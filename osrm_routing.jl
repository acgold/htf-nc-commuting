using DataFrames
using CSV
using HTTP
using JSON
using GeoInterface
using ProgressMeter

# Function to query a local OSRM instance to get commutes
function get_osrm_routes(x::DataFrame, csv_path::String, overwrite::Bool=true)
    processed_df = DataFrame(Dict("row"=>Int64(0), "code"=>"OK", "route_duration"=>Float64(1.1), "route_distance"=>Float64(1.1), "geom"=>"NaN"))
    number_of_rows = nrow(x)

    if overwrite == true
        CSV.write(csv_path, processed_df, header=true)
        processed_df = DataFrame()
    end

    @showprogress for row in eachrow(x)
        url_string = "http://127.0.0.1:5000/route/v1/car/" * string(row.h_lon) * "," * string(row.h_lat) * ";" * string(row.w_lon) * "," * string(row.w_lat) * "?alternatives=false&geometries=polyline6&steps=false&overview=full&annotations=nodes"
        r = HTTP.request("GET",url_string)
        body_text = JSON.parse(String(r.body))
        formatted_response = Dict("row" => Int64(row.row), "code"=>string(body_text["code"]),"route_duration"=>Float64(body_text["routes"][1]["duration"]),"route_distance"=>Float64(body_text["routes"][1]["distance"]),"geom"=>string(body_text["routes"][1]["geometry"]), "nodes"=>string(body_text["routes"]))
        formatted_response_df = DataFrame(formatted_response)
        append!(processed_df, formatted_response_df)
        if rownumber(row) % 10000 == 0 || rownumber(row) == number_of_rows
            CSV.write(csv_path, processed_df, append=true)
            processed_df = DataFrame()
            # GC.gc()
        end
    end
end

# Load the LODES dataset that has commutes for people that live in NC.
# We have added the coordinates of the census block centroids, and we will
# create routes for each commute and get distance, duration, and a polyline
lodes = DataFrame(CSV.File("data/lodes.csv"))

# the route data are written to a csv, so we don't need the end product of the function
osrm_routes = @time get_osrm_routes(lodes, "data/osrm_routes.csv")