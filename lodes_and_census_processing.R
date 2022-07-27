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
write_csv(nc_blocks, "data/blocks.csv")

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

# Filter out lodes data so we are left with only people who live within NC
dt <- as.data.table(nc_lodes_w_coords |> 
                      filter(h_geocode %in% nc_blocks$GEOID))

# Write these data to csv, so we can load it into Julia to query OSRM
readr::write_csv(dt, "data/lodes.csv")

