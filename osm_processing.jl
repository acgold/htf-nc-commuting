using OpenStreetMapX
import SimpleFeatures as sf
using DataFrames
import ArchGDAL as AG
using ArchGDAL
using Parsers
import GeoFormatTypes as GFT
using ProgressMeter
using CSV
using ProgressMeter
using GeoInterface

# Read in and parse the PBF file
osm_path = "/Volumes/my_hd/osrm/nc_osrm/north-carolina-latest.osm.pbf"

osmdata = get_map_data(osm_path)
node_ids = collect(keys(osmdata.nodes))

# Create an empty Dict for node lat/long data and populate
node_geo_dict = Dict()

@showprogress for i in node_ids #116.165786 seconds (269.81 M allocations: 19.727 GiB, 77.79% gc time, 0.02% compilation time)
    z = reverse(Parsers.parse.(Float64, split(OpenStreetMapX.node_to_string(i, osmdata), ",")))
    node_geo_dict[i]= z
end

# Pull out the ways data
ways = osmdata.roadways #id, nodes, tags

# make edge list where every road SEGMENT is a separate line
way_geo_data = DataFrames.DataFrame()

@showprogress for i = 1:length(ways) #5 minutes
    selected_nodes = ways[i,].nodes
    tag_keys = keys(ways[i,].tags)
    b_or_t = "bridge" in tag_keys || "tunnel" in tag_keys
    
    # Parse number of lanes or assign the default (2 lanes)
    if "lanes" in tag_keys
        lanes = tryparse(Int64, ways[i,].tags["lanes"])

        if isnothing(lanes)
            lanes = 2
        end
    else 
        lanes = 2
    end

    # only collect the roadway if it is not a bridge or tunnel
    if b_or_t == false
        for j = 1:(length(selected_nodes)-1)
            append!(way_geo_data, DataFrames.DataFrame(way_id = ways[i,].id, from_node_id=selected_nodes[j], to_node_id = selected_nodes[j+1], lanes = lanes, geom = ArchGDAL.createlinestring([node_geo_dict[selected_nodes[j]][1],node_geo_dict[selected_nodes[j+1]][1]], [node_geo_dict[selected_nodes[j]][2],node_geo_dict[selected_nodes[j+1]][2]])))
        end
    end
end


# convert the list of dataframe containinig individual road segments into a SimpleFeature object
ways_sf = df_to_sf(way_geo_data, GFT.EPSG(4326))

# Now re-create the roadways by combining the road segments by "way_id"
ways_sf_mls = sf.st_cast(ways_sf, "multilinestring"; groupid = "way_id")

# Write unprojected SimpleFeature objects to file
@time sf.st_write("data/nc_road_lines_w_nodes.gpkg", ways_sf) #4 minutes. MUST write to local disk and not external HD for speed. Otherwise will freeze
@time sf.st_write("data/nc_road_lines.gpkg", ways_sf_mls) #43 seconds. MUST write to local disk and not external HD for speed. Otherwise will freeze

# Reproject from EPSG 4326 to UTM 17N (EPSG 6346). Make sure the 'order' is ':trad'
@time ways_sf_proj = sf.st_transform(ways_sf, GFT.EPSG(6346), order = :trad)
@time ways_sf_mls_proj = sf.st_transform(ways_sf_mls, GFT.EPSG(6346), order = :trad)

# write projected SimpleFeature objects to file, ~7 minutes
@time sf.st_write("data/nc_road_lines_w_nodes_proj.gpkg", ways_sf_proj) #MUST write to local disk and not external HD for speed. Otherwise will freeze
@time sf.st_write("data/nc_road_lines_proj.gpkg", ways_sf_mls_proj) #MUST write to local disk and not external HD for speed. Otherwise will freeze

# calculate buffer distance based on lanes. Number of lanes * 2.5 meters (units of CRS)
ways_sf_mls_proj.df.buffer_distance = ways_sf_mls_proj.df.lanes * 2.5

# buffer based on buffer distance column
@time ways_sf_mls_buff = sf.st_buffer(ways_sf_mls_proj, "buffer_distance") # 20 minutes
@time sf.st_write("data/nc_road_lines_proj_buff.gpkg", ways_sf_mls_buff) #MUST write to local disk and not external HD for speed. Otherwise will freeze

#------------------------- Reading created files ------------------------------------
# # read dfs from file if necessary
# @time ways_sf = sf.st_read("data/nc_road_lines_w_nodes.gpkg")
# @time ways_sf_mls = sf.st_read("data/nc_road_lines.gpkg")
# @time ways_sf_mls_proj_buff = sf.st_read("data/nc_road_lines_proj_buff.gpkg")

#-----------------------------------------------------------------------------------------------

################################################################
#############  BEFORE THE FOLLOWING STEPS, #####################
#############  THE INTERSECTION OF BUFFERED  ###################      
#############  ROADS AND HTF SHOULD BE  ########################
#############  CALCULATED W/ARCGIS PRO  ########################
################################################################

#--------------------------------------------------------------

# Speed file to be used with osrm
# Read in the csv
impacted_roads = DataFrame(CSV.File("/Volumes/my_hd/htf_on_roads/carteret_test_folder/impacted_roads.csv"))

# make a subset of dataframe
impacted_roads_speed = DataFrame(from = impacted_roads.from_node_id, to = impacted_roads.to_node_id, speed = 0)

# copy the original dataframe and swap the from/to column so we say the speed is zero for both directions
impacted_roads_speed_copy = DataFrames.rename(DataFrames.copy(impacted_roads_speed), Dict("from" => "to", "to"=> "from"))

# select make sure the dataframe is ordered correctly (same columns)
select!(impacted_roads_speed_copy, [:from, :to, :speed])

# combine!
append!(impacted_roads_speed, impacted_roads_speed_copy)

impacted_roads_speed
