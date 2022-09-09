library(terra)

home_dir <- "/pine/scr/a/c/acgold/output/model_results"

water_levels <- c(0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0)
water_level_labels <- c("zero_to_point1", "zero_to_point2", "zero_to_point3", "zero_to_point4", "zero_to_point5", "zero_to_point6", "zero_to_point7", "zero_to_point8", "zero_to_point9", "zero_to_1") #

buffered_osm_ways <- terra::vect("/pine/scr/a/c/acgold/output/osm/ways/buffered_osm_ways.gpkg")

for(x in 1:length(water_levels)){
    htf_on_rds <- terra::vect(file.path(home_dir, water_level_labels[x], "htf_on_rds.fgb"))
    
    intersection <- terra::intersect(buffered_osm_ways, htf_on_rds)

    terra::writeVector(intersection, file.path(home_dir, water_level_labels[x], "htf_on_rds_int.gpkg"))
}