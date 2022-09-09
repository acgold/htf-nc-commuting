#!/bin/bash

#SBATCH -p general
#SBATCH -N 1
#SBATCH --mem=150g
#SBATCH -n 16
#SBATCH -t 1-
#SBATCH --mail-type=end
#SBATCH --mail-user=acgold@live.unc.edu

eval "$(conda shell.bash hook)"  

conda activate osrm

gdal_polygonize.py /pine/scr/a/c/acgold/output/model_results/water_mask/htf_on_rds.tif -b 1 -f "FlatGeobuf" /pine/scr/a/c/acgold/output/model_results/water_mask/htf_on_rds.fgb OUTPUT DN;

# gdal_polygonize.py /pine/scr/a/c/acgold/output/model_results/zero_to_1/htf_on_rds.tif -b 1 -f "FlatGeobuf" /pine/scr/a/c/acgold/output/model_results/zero_to_1/htf_on_rds.fgb OUTPUT DN;
# gdal_polygonize.py /pine/scr/a/c/acgold/output/model_results/zero_to_point1/htf_on_rds.tif -b 1 -f "FlatGeobuf" /pine/scr/a/c/acgold/output/model_results/zero_to_point1/htf_on_rds.fgb OUTPUT DN;
# gdal_polygonize.py /pine/scr/a/c/acgold/output/model_results/zero_to_point2/htf_on_rds.tif -b 1 -f "FlatGeobuf" /pine/scr/a/c/acgold/output/model_results/zero_to_point2/htf_on_rds.fgb OUTPUT DN;
# gdal_polygonize.py /pine/scr/a/c/acgold/output/model_results/zero_to_point3/htf_on_rds.tif -b 1 -f "FlatGeobuf" /pine/scr/a/c/acgold/output/model_results/zero_to_point3/htf_on_rds.fgb OUTPUT DN;
# gdal_polygonize.py /pine/scr/a/c/acgold/output/model_results/zero_to_point4/htf_on_rds.tif -b 1 -f "FlatGeobuf" /pine/scr/a/c/acgold/output/model_results/zero_to_point4/htf_on_rds.fgb OUTPUT DN;
# gdal_polygonize.py /pine/scr/a/c/acgold/output/model_results/zero_to_point5/htf_on_rds.tif -b 1 -f "FlatGeobuf" /pine/scr/a/c/acgold/output/model_results/zero_to_point5/htf_on_rds.fgb OUTPUT DN;
# gdal_polygonize.py /pine/scr/a/c/acgold/output/model_results/zero_to_point6/htf_on_rds.tif -b 1 -f "FlatGeobuf" /pine/scr/a/c/acgold/output/model_results/zero_to_point6/htf_on_rds.fgb OUTPUT DN;
# gdal_polygonize.py /pine/scr/a/c/acgold/output/model_results/zero_to_point7/htf_on_rds.tif -b 1 -f "FlatGeobuf" /pine/scr/a/c/acgold/output/model_results/zero_to_point7/htf_on_rds.fgb OUTPUT DN;
# gdal_polygonize.py /pine/scr/a/c/acgold/output/model_results/zero_to_point8/htf_on_rds.tif -b 1 -f "FlatGeobuf" /pine/scr/a/c/acgold/output/model_results/zero_to_point8/htf_on_rds.fgb OUTPUT DN;
# gdal_polygonize.py /pine/scr/a/c/acgold/output/model_results/zero_to_point9/htf_on_rds.tif -b 1 -f "FlatGeobuf" /pine/scr/a/c/acgold/output/model_results/zero_to_point9/htf_on_rds.fgb OUTPUT DN;
