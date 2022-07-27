library(lehdr)
library(tidycensus)
library(tidyverse)
library(data.table)

# Add the census API key to env vars and sign in to API
source(census_env_var.R)
census_api_key(Sys.getenv("census_api_key"))

# Download LODES data for NC
nc_lodes <- grab_lodes(state="NC", year = 2019, lodes_type = "od", job_type = "JT00", segment = "S000", state_part = "main")

# Download census block data for NC
nc_blocks <- get_decennial(geography = "block", variables = "H010001", state = "NC", geometry = T)

# Write census block data to file. We will be using the CSV later
# sf::write_sf(nc_blocks, "carteret_blocks_text.gpkg")
write_csv(nc_blocks, "data/carteret_blocks_test.csv")

# Get the centroid of each census block and extract coordinates
nc_blocks_centroid <- nc_blocks |> 
  sf::st_centroid() |> 
  sf::st_coordinates() |> 
  as_tibble()

nc_blocks_coords <- nc_blocks_centroid |> 
  sf::st_coordinates(.) |> 
  as_tibble() |> 
  mutate(GEOID = nc_blocks_centroid$GEOID, .before = "X")

# Combine the census block centroid coordinates with the LODES data
nc_lodes_w_coords <- nc_lodes |> 
  left_join(nc_blocks_coords |> select(w_geocode = GEOID, w_lat = Y, w_lon = X)) |> 
  left_join(nc_blocks_coords |> select(h_geocode = GEOID, h_lat = Y, h_lon = X)) |> 
  mutate(row = row_number(), .before = w_geocode)

# nc_lodes_w_coords |> 
#   filter(h_geocode %in% nc_blocks$GEOID) |> 
#   sfheaders::sf_linestring(x = c("h_lon", "w_long"), y = c("h_lat", "w_lat"), linestring_id = "row")

# Filter out lodes data so we are left with only people who live within NC
dt <- as.data.table(nc_lodes_w_coords |> 
                      filter(h_geocode %in% nc_blocks$GEOID))

# Write these data to csv, so we can load it into Julia to query OSRM
readr::write_csv(dt, "data/lodes.csv")


# Extras
z <- dt[
  , {
    geometry <- sf::st_linestring(x = matrix(c(h_lon, w_lon, h_lat, w_lat), nrow = 2, ncol = 2))
    geometry <- sf::st_sfc(geometry, crs = 4269)
    geometry <- sf::st_sf(geometry = geometry)
  }
  , by = row
]

z_sf <- sf::st_as_sf(z) |> 
  left_join(nc_lodes_w_coords |> 
              # slice(1:10000) |> 
              select("row", "S000"))


z_sf |> 
  mapview(zcol = "S000", alpha = 0.1)


library(osrm)

library(foreach)

b <- foreach(i=1:nrow(z_sf), .combine="bind_rows") %do%{
  
  request <- httr::GET(url = paste0("http://127.0.0.1:5000/route/v1/car/",z_sf$geometry[[i]][1],",",z_sf$geometry[[i]][3],";",z_sf$geometry[[i]][2],",",z_sf$geometry[[i]][4],"?alternatives=false&geometries=geojson&steps=false&overview=simplified"))
  response <- jsonlite::fromJSON(rawToChar(request$content))
  response$routes$geometry
  
  route <- osrm::osrmRoute(src = z_sf[i,] |> st_cast("POINT") |> slice(1),
                           dst = z_sf[i,] |> st_cast("POINT") |> slice(2),
                           osrm.server = "http://0.0.0.0:5000/",
                           returnclass = "sf")
  return(route)
}

z |> mapview()


library(osmextract)

osmextract::oe_vectortranslate(file_path = "/Volumes/my_hd/osrm/nc_osrm/north-carolina-latest.osm.pbf", layer = "other_relations")

library(osmdata)

beaufort_bb <- osmdata::getbb("Beaufort, North Carolina")


building_csv <- read_csv("/Volumes/my_hd/osrm/NC_Buildings_Footprints_(2010).csv")

test_routes <- read_csv("/Users/adam/Library/CloudStorage/OneDrive-SharedLibraries-UniversityofNorthCarolinaatChapelHill/Piehler Lab - Documents/Coastal Stormwater and SLR/people/analysis/data_downloads/full_test_routes.csv") |> 
  mutate(w_geocode = as.character(w_geocode),
         h_geocode = as.character(h_geocode))

test_routes_sf <- test_routes |> sf::st_as_sf(wkt = "geom", crs = 4269)

nc_blocks |> 
  left_join(test_routes, by = c("GEOID" = "h_geocode")) |> 
  group_by(GEOID, value) |> 
  summarise(mean_duration = sum(S000, na.rm=T)) |> 
  filter(value > 0) |> 
  mapview(zcol = "mean_duration")
library(leaflet)

leaflet() %>%
  addProviderTiles(provider = providers$CartoDB.DarkMatter) %>%
  addGlPolylines(data = test_routes_sf, group = "lines")

test_routes_sf |> 
  # slice(1:1000) |> 
  mapview()
