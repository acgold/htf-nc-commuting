import os
# Set the working directory
os.chdir("/pine/scr/a/c/acgold")


from pickletools import uint8
import rioxarray as rio
import xarray as xr
import dask
from dask.diagnostics import ProgressBar
import numpy as np
from pyproj import CRS

import multiprocessing
import multiprocessing.popen_spawn_posix
import threading

from dask.distributed import Client, LocalCluster, Lock
from dask.utils import SerializableLock

from pathlib import Path
from scipy.stats import norm

import numpy as np
import fiona
import rasterio
import rasterio.features
from fiona.crs import to_string
from shapely.geometry import shape, mapping
from shapely.geometry.multipolygon import MultiPolygon


def create_water_surfaces(dem_xarray, max_wl, directory, min_wl = 0):
    # Create directory if needed
    Path(directory).mkdir(parents=True, exist_ok= True)
    
    # Set rmse of objects
    dem_rmse = 35 #cm
    conv_rmse = 10 #cm
    muc = np.sqrt(dem_rmse**2 + conv_rmse**2)/100 # in meters. About 0.364

    spatial_ref = CRS.from_cf(dem_xarray.spatial_ref.attrs)
    
    #-------------- Step 1 --------------------
    print("- Modelling water level between", min_wl, "and", max_wl, "meters")
    print("(1/5) extracting land DEM....")
    
    max_land_dem = max_wl - norm.ppf(.2) * muc
    
    land_dem = xr.where((dem_xarray <= max_land_dem) & (dem_xarray > min_wl) , dem_xarray, 0)
    land_dem.rio.set_nodata(0, inplace = True)
    land_dem = land_dem.where(land_dem != land_dem.rio.nodata)
    land_dem.rio.write_nodata(0, encoded = True, inplace = True)
    land_dem.rio.write_crs(spatial_ref, inplace=True)
    
    # Write the land dem to disk with dask
    with ProgressBar():
        land_dem.rio.to_raster(Path(directory, "land_dem.tif"), windowed=True, lock=threading.Lock(), compress='lzw')
    
    
    #-------------- Step 2 --------------------
    print("(2/5) calculating water depth....")

    water_depth = max_wl - land_dem
    water_depth.rio.write_crs(spatial_ref, inplace=True)
    
    with ProgressBar():
        water_depth.rio.to_raster(Path(directory, "water_depth.tif"), windowed=True, lock=threading.Lock(), compress='lzw')
    
    
    #-------------- Step 3 --------------------
    print("(3/5) calculating inundation error....")
    
    inundation_error = xr.apply_ufunc(norm.cdf, (max_wl - land_dem)/muc, dask = "parallelized")
    inundation_error.rio.write_crs(spatial_ref, inplace=True)

    with ProgressBar():
        inundation_error.rio.to_raster(Path(directory, "error.tif"), windowed=True, lock=threading.Lock(), compress='lzw')


    #-------------- Step 4 --------------------
    print("(4/5) classifying error classes ....")
        
    error_class = xr.where(inundation_error > 0.5, inundation_error, -1)
    error_class.rio.set_nodata(-1, inplace = True)
    
    error_class = xr.where(error_class >= 0.8, 1.0, error_class)
    error_class = xr.where((error_class < 0.8) & (error_class > 0), 0, error_class)
    error_class = error_class.astype("int16")
    
    error_class = error_class.where(error_class != error_class.rio.nodata)
    error_class.rio.write_nodata(-1, encoded = True, inplace = True)

    error_class.rio.write_crs(spatial_ref, inplace=True)

    with ProgressBar():
        error_class.rio.to_raster(Path(directory, "error_class.tif"),dtype= "int16", windowed=True, lock=threading.Lock(), compress='lzw') 

    #-------------- Step 5 --------------------
    print("(5/5) converting error classes to polygon ....")
    
    with rasterio.open(Path(directory, "error_class.tif")) as src:
        crs = to_string(src.crs)
        src_band = src.read(1)
        # Keep track of unique pixel values in the input band
        unique_values = np.array([0, 1], dtype="int16")
        # np.unique(src_band)
        # Polygonize with Rasterio. `shapes()` returns an iterable
        # of (geom, value) as tuples
        shapes = list(rasterio.features.shapes(src_band, transform=src.transform))

    shp_schema = {
        'geometry': 'MultiPolygon',
        'properties': {'pixelvalue': 'int'}
    }
    
    # Get a list of all polygons for a given pixel value
    # and create a MultiPolygon geometry with shapely.
    # Then write the record to an output shapefile with fiona.
    # We make use of the `shape()` and `mapping()` functions from
    # shapely to translate between the GeoJSON-like dict format
    # and the shapely geometry type.
    with fiona.open(Path(directory, "error_class.shp"), 'w', 'ESRI Shapefile', shp_schema, crs) as shp:
        for pixel_value in unique_values:
            polygons = [shape(geom) for geom, value in shapes
                        if value == pixel_value]
            multipolygon = MultiPolygon(polygons)
            shp.write({
                'geometry': mapping(multipolygon),
                'properties': {'pixelvalue': int(pixel_value)}
            })
        
    return print("Done!")

#------------------ modelling loop -------------------------

# Create necessary folders
Path("output/dems").mkdir(parents=True, exist_ok= True)
Path("output/model_results").mkdir(parents=True, exist_ok= True)


# Load original DEM
# dem = "/Volumes/my_hd/htf_on_roads/noaa_elevation/North_Carolina_CoNED_Topobathy_DEM_1m.tif"
# dem = "/Volumes/my_hd/htf_on_roads/noaa_elevation/xarray_test/land_dem.tif"
# dem = "/Volumes/my_hd/htf_on_roads/noaa_elevation/carteret_test_dem.tif"
dem = "North_Carolina_CoNED_Topobathy_DEM_1m.tif"
dem_xarray = rio.open_rasterio(dem, chunks=True, lock=False)


# Load conversion raster
# conversion = "/Volumes/my_hd/htf_on_roads/files_for_longleaf/resampled_conv_rast.tif"
conversion = "resampled_conv_rast.tif"
conversion_xarray = rio.open_rasterio(conversion, chunks=True, lock=False)

mhhw_dem = dem_xarray - conversion_xarray
mhhw_dem.rio.set_nodata(dem_xarray.rio.nodata, inplace = True)
mhhw_dem = mhhw_dem.where(mhhw_dem != mhhw_dem.rio.nodata)
mhhw_dem.rio.write_nodata(mhhw_dem.rio.nodata, encoded = True, inplace = True)

with ProgressBar():
    mhhw_dem.rio.to_raster(Path("output/dems/mhhw_dem_1m.tif"), windowed=True, lock=threading.Lock(), compress='lzw') 


# Make a smaller DEM so we can do the following calcs quicker
mini_dem = xr.where((mhhw_dem >= 0) & (mhhw_dem <= 5), mhhw_dem, dem_xarray.rio.nodata)
mini_dem.rio.set_nodata(dem_xarray.rio.nodata, inplace = True)
mini_dem = mhhw_dem.where(mini_dem != mini_dem.rio.nodata)
mini_dem.rio.write_nodata(mini_dem.rio.nodata, encoded = True, inplace = True)

with ProgressBar():
    mini_dem.rio.to_raster(Path("output/dems/mhhw_zero_to_5m.tif"), windowed=True, lock=threading.Lock(), compress='lzw') 


# make water level below zero m to get permanent water surface
create_water_surfaces(dem_xarray = mhhw_dem,
                      max_wl = 0,
                      min_wl = -100,
                      directory = "output/model_results/water_mask")


# Iterate through max water levels to model
water_levels = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
water_level_labels = ["zero_to_point1", "zero_to_point2", "zero_to_point3", "zero_to_point4", "zero_to_point5", "zero_to_point6", "zero_to_point7", "zero_to_point8", "zero_to_point9", "zero_to_1"]

for index, value in enumerate(water_levels):
    create_water_surfaces(dem_xarray = mini_dem,
                          max_wl = value,
                          min_wl = 0,
                          directory = Path("output/model_results/",water_level_labels[index]))