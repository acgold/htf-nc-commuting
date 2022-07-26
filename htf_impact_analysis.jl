import SimpleFeatures as sf
using DataFrames
import ArchGDAL as AG
using ProgressMeter
using ProgressMeter
using GeoInterface

#------------------------- Measuring and summarizing impact of HTF on roadways -------------------
# Load road segments. We will use the 'road_segments' for every calculation
road_segments = sf.st_read("data/nc_road_lines_w_nodes_proj.gpkg")

# Define our 'impact' function. Here's how it works:
#   STEPS
#   ------
#   1) Based on buffered roadways and HTF, we are going 
#   to find the roadway segments that may be impacted by HTF (based on broader 'way_id').
#
#   2) We will filter down more to find the specific road segments that intersect HTF, and then buffer them accordingly
#
#   3) We will use the road centerline of each impacted road segment, to create perpindicular lines every 1 meter that 
#   exactly span the roadway.
#
#   4) HTF polygons contain the road id (:way_id) and the confidence class (low or high confidence). We want to estimate 
#   the roadway width coverage of each confidence class of HTF. We do this by taking the length of each perpindicular line 
#   across the road, erasing the high confidence HTF polygons from the line, finding the new length, then doing the same
#   thing with the low confidence HTF polygons. Each perpindicular roadway line now has a high confidence HTF roadway width
#   coverage and a low confidence HTF roadway coverage that are in % of roadway width. These will be reported as a range of
#   minimum roadway coverage (high confidence) and maximum roadway coverage (high confidence + low confidence)

function classify_road_flooding(;road_segments::sf.SimpleFeature, htf_polygons::sf.SimpleFeature)

    roads_affected = htf_polygons.df.way_id
        
    filtered_road_segments = filter(:way_id => n -> n in roads_affected, road_segments.df)
    filtered_road_segments.buffer_distance =  filtered_road_segments.lanes * 2.5

    filtered_road_segments[!, :geom] = sf.sfgeom_to_gdal(filtered_road_segments.geom)

    htf_polygons_df = sf.sf_to_df(htf_polygons);
    combined_htf_polygons_df = sf.sf_to_df(sf.st_cast(htf_polygons, "multipolygon"; groupid="gridcode"))

    high_confidence_htf_polygons_df = filter(:gridcode => n -> n === 1, combined_htf_polygons_df)
    low_confidence_htf_polygons_df = filter(:gridcode => n -> n === 0, combined_htf_polygons_df)

    road_segments_impacted = DataFrame()

    @showprogress for row in eachrow(htf_polygons_df)
        for i in 1:nrow(filtered_buffered_roads)
            if AG.intersects(row.geom, AG.buffer(filtered_road_segments.geom[i], filtered_road_segments.buffer_distance[i])) == true
                append!(road_segments_impacted, DataFrame(filtered_road_segments[i,:]))
            end
        end
    end

    impact_classified_roads = DataFrame()

    @showprogress for row in eachrow(road_segments_impacted)
        road = row.geom
        buffered_road = AG.buffer(row.geom, row.buffer_distance)

        road_coords = GeoInterface.coordinates(road)

        rise_run = (road_coords[2] - road_coords[1])
        perp_angle = (-1 * rise_run[1])/rise_run[2]
    
        line_clone = AG.clone(road)
        pt_coords = GeoInterface.coordinates(AG.segmentize!(line_clone, 1))
    
        line_list = []
        hc_erased_line_list = []
        lc_erased_line_list = []

        for i in pt_coords
            new_line = AG.createlinestring()
            AG.addpoint!(new_line, i[1] + (row.buffer_distance[1]), i[2] + ((row.buffer_distance[1]) * perp_angle))
            AG.addpoint!(new_line, i[1] - (row.buffer_distance[1]), i[2] - ((row.buffer_distance[1]) * perp_angle))

            new_line_int = AG.intersection(new_line, buffered_road)
            push!(line_list, new_line_int)

            if nrow(high_confidence_htf_polygons_df) > 0
                hc_erased_line = AG.difference(new_line_int, high_confidence_htf_polygons_df.geom[1])
                push!(hc_erased_line_list, hc_erased_line)
            else
                push!(hc_erased_line_list, new_line_int)
            end

            if nrow(low_confidence_htf_polygons_df) > 0
                lc_erased_line = AG.difference(new_line_int, low_confidence_htf_polygons_df.geom[1])
                push!(lc_erased_line_list, lc_erased_line)
            else
                push!(lc_erased_line_list, new_line_int)
            end
        end    
    
        new_df = repeat(select(DataFrame(row), Not(:geom)), length(line_list))
        new_df.length = AG.geomlength.(line_list)
        new_df.hc_length = AG.geomlength.(hc_erased_line_list)
        new_df.lc_length = AG.geomlength.(lc_erased_line_list)

        new_df.hc_percent_covered = 100 .- ((new_df.hc_length./new_df.length)*100)
        new_df.lc_percent_covered = 100 .- ((new_df.lc_length./new_df.length)*100)
        
        new_df.min_percent_covered = new_df.hc_percent_covered
        new_df.max_percent_covered = new_df.hc_percent_covered + new_df.lc_percent_covered

        n_min_75_100 = sum(new_df.min_percent_covered .>= 75)
        n_min_50_75 = sum(new_df.min_percent_covered .>= 50 .&& new_df.min_percent_covered .< 75)
        n_min_25_50 = sum(new_df.min_percent_covered .>= 25 .&& new_df.min_percent_covered .< 50)
        n_min_0_25 = sum(new_df.min_percent_covered .> 0 .&& new_df.min_percent_covered .< 25)
        n_min_0 = sum(new_df.min_percent_covered .== 0.0)

        n_max_75_100 = sum(new_df.max_percent_covered .>= 75)
        n_max_50_75 = sum(new_df.max_percent_covered .>= 50 .&& new_df.max_percent_covered .< 75)
        n_max_25_50 = sum(new_df.max_percent_covered .>= 25 .&& new_df.max_percent_covered .< 50)
        n_max_0_25 = sum(new_df.max_percent_covered .> 0 .&& new_df.max_percent_covered .< 25)
        n_max_0 = sum(new_df.max_percent_covered .== 0.0)

        # Impact class: 3 = 75-100% coverage of HTF on road, 2 = 50 - 75%, 1 = 25 - 50%, 0 = 0 - 25%
        min_impact_class = [ifelse(n_min_75_100 > 2, 3, 
        ifelse(n_min_50_75 > 2, 2,
        ifelse(n_min_25_50 > 2, 1, 0)))]

        max_impact_class = [ifelse(n_max_75_100 > 2, 3, 
        ifelse(n_max_50_75 > 2, 2,
        ifelse(n_max_25_50 > 2, 1, 0)))]

        new_row = DataFrame(deepcopy(row))
        new_row.min_impact_class = min_impact_class
        new_row.n_min_75_100 = [n_min_75_100]
        new_row.n_min_50_75 = [n_min_50_75]
        new_row.n_min_25_50 = [n_min_25_50]
        new_row.n_min_0_25 = [n_min_0_25]
        new_row.n_min_0 = [n_min_0]

        new_row.max_impact_class = max_impact_class
        new_row.n_max_75_100 = [n_max_75_100]
        new_row.n_max_50_75 = [n_max_50_75]
        new_row.n_max_25_50 = [n_max_25_50]
        new_row.n_max_0_25 = [n_max_0_25]
        new_row.n_max_0 = [n_max_0]

        append!(impact_classified_roads, new_row)
     end
     
     return impact_classified_roads
end

htf_polygons = sf.st_read("htf_polygons_location_here")

@time htf_polygons_impact_df = classify_road_flooding(;road_segments=road_segments, htf_polygons=htf_polygons)  