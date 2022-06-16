using OpenStreetMapX
using GeoDataFrames
using DataFrames
using ArchGDAL
using Parsers
import GeoFormatTypes as GFT
using ProgressMeter
using CSV

osm_path = "/Volumes/my_hd/osrm/nc_osrm/north-carolina-latest.osm.pbf"

osmdata = get_map_data(osm_path)
node_ids = collect(keys(osmdata.nodes))

node_geo_dict = Dict()

@showprogress for i in node_ids #116.165786 seconds (269.81 M allocations: 19.727 GiB, 77.79% gc time, 0.02% compilation time)
    z = reverse(Parsers.parse.(Float64, split(OpenStreetMapX.node_to_string(i, osmdata), ",")))
    node_geo_dict[i]= z
end

ways = osmdata.roadways #id, nodes, tags
way_geo_data = GeoDataFrames.DataFrame()

@showprogress for i = 1:length(ways) #5 minutes
    selected_nodes = ways[i,].nodes
    tag_keys = keys(ways[i,].tags)
    b_or_t = "bridge" in tag_keys || "tunnel" in tag_keys
    
    if b_or_t == false
        for j = 1:(length(selected_nodes)-1)
            append!(way_geo_data, GeoDataFrames.DataFrame(way_id = ways[i,].id, from_node_id=selected_nodes[j], to_node_id = selected_nodes[j+1], geom = ArchGDAL.createlinestring([node_geo_dict[selected_nodes[j]][1],node_geo_dict[selected_nodes[j+1]][1]], [node_geo_dict[selected_nodes[j]][2],node_geo_dict[selected_nodes[j+1]][2]])))
        end
    end
end


@time GeoDataFrames.write("data/nc_road_lines_w_nodes.gpkg", way_geo_data; crs=GFT.EPSG(4326)) #4 minutes. MUST write to local disk and not external HD for speed. Otherwise will freeze

# Create the impacted roads speed file to be used with osrm
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
# using JSON

# microsoft_roads = DataFrame(CSV.File("/Volumes/my_hd/htf_on_roads/NC_microsoft_roads.tsv", delim = '\t'))

# microsoft_road_string = JSON.parse.(microsoft_roads[:,1])

# function dict2linestring(x::Dict)
#     p = ArchGDAL.createlinestring()
#     for i in 1:length(x["geometry"]["coordinates"])
#         ArchGDAL.addpoint!(p, x["geometry"]["coordinates"][i][1], x["geometry"]["coordinates"][i][2])
#     end

#     GeoDataFrames.DataFrame(geom = p)
# end


# microsoft_roads_df = GeoDataFrames.DataFrame()

# @showprogress for i in 1:length(microsoft_road_string)
#     append!(microsoft_roads_df, dict2linestring(microsoft_road_string[i]))
# end

# @time GeoDataFrames.write("data/microsoft_roads.gpkg", microsoft_roads_df; crs=GFT.EPSG(4326)) #4 minutes. MUST write to local disk and not external HD for speed. Otherwise will freeze

# ArchGDAL.fromJSON(test_geo_string)

# collected_json_strings = Dict("type"=>"FeatureCollection", "features"=> [JSON.parse.(microsoft_roads[1:1000,1])])

# stringdata = JSON.json(collected_json_strings)

# open("write_test.geojson", "w") do f
#     write(f, stringdata)
#  end

