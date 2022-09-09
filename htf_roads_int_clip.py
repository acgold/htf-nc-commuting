import geopandas
from pathlib import Path
import os
    
os.chdir("/pine/scr/a/c/acgold")

# Iterate over water levels
water_levels = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0] 
water_level_labels = ["zero_to_point1", "zero_to_point2", "zero_to_point3", "zero_to_point4", "zero_to_point5", "zero_to_point6", "zero_to_point7", "zero_to_point8", "zero_to_point9", "zero_to_1"] #

buffered_rds = geopandas.read_file("output/osm/ways/buffered_osm_ways.gpkg")

for index, value in enumerate(water_levels):
    fgb = geopandas.read_file(Path("output/model_results", water_level_labels[index], "htf_on_rds.fgb")).to_crs(buffered_rds.crs)
    int = geopandas.overlay(buffered_rds, fgb)
    
    int.to_file(Path("output/model_results", water_level_labels[index], "htf_on_rds_int.gpkg"))
    
    
