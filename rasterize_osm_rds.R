library(terra)

# home_folder <- "/pine/scr/a/c/acgold"

#---------- 1. Read in the OSM way gpkg ----------
osm_ways <- terra::vect("/pine/scr/a/c/acgold/output/osm/ways/osm_ways.gpkg")
# osm_ways <- terra::vect("data/osm_ways.gpkg")


#---------- 2. Parse the lanes + calc buffer distance + buffer ----
osm_ways <- osm_ways[,c("id", "lanes")] 
osm_ways$lanes = as.numeric(osm_ways$lanes)
osm_ways$lanes[is.na(osm_ways$lanes)] <- 2
osm_ways$buffer_distance <- osm_ways$lanes * 2.5

buffered_osm_ways <- osm_ways |>
  terra::buffer(osm_ways$buffer_distance)

rm(osm_ways)

#---------- 3. Write the buffer to file -----------------
terra::writeVector(buffered_osm_ways, "/pine/scr/a/c/acgold/output/osm/ways/buffered_osm_ways.gpkg")

#--------- 4. Rasterize the roads to the HTF rasters -----------
template_raster <- terra::rast("/pine/scr/a/c/acgold/xarray_output/output/model_results/zero_to_point5/error_class.tif")
 
terra::rasterize(x=buffered_osm_ways, y=template_raster, field = 1, touches = TRUE, filename = "/pine/scr/a/c/acgold/output/osm/ways/buffered_osm_ways.tif", wopt = list(datatype = "INT4S"))
