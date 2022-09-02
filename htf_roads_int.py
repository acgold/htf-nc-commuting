import dask_geopandas
import dask
from dask.diagnostics import ProgressBar
import xarray as xr
import rioxarray as rio
import os
from pyproj import CRS
import threading

import numpy as np
import fiona
import rasterio
import rasterio.features
from fiona.crs import to_string
from shapely.geometry import shape, mapping
from shapely.geometry.multipolygon import MultiPolygon
from pathlib import Path


def make_intersecting_polygons(x, mask, raster_output, vector_output, mask_value = 1, nodataval = -1):
    """Takes the two inputs that are the same dimensions and crs but hold different values
    and create polygons representing their intersection.

    Args:
        x (xarray DataArray): An xarray.DataArray with the same dimensions as `y`, chunked with Dask
        mask (xarray DataArray): An xarray.DataArray with the same dimensions as `x`, chunked with Dask
    """    
    
    # Find the overlap between the inputs x and mask
    spatial_ref = CRS.from_cf(x.spatial_ref.attrs)
    
    masked_raster = xr.where((mask == mask_value), x, nodataval)
    masked_raster.rio.set_nodata(nodataval, inplace = True)
    masked_raster = masked_raster.astype("int16")
    
    masked_raster = masked_raster.where(masked_raster != masked_raster.rio.nodata)
    masked_raster.rio.write_nodata(nodataval, encoded = True, inplace = True)

    masked_raster.rio.write_crs(spatial_ref, inplace=True)
    
    masked_raster.rio.to_raster(raster_output, dtype= "int16", windowed=True, lock=threading.Lock(), tiled = True, compress='lzw', BIGTIFF="YES") 

    # Turn the raster into vector format
    with rasterio.open(raster_output) as src:
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
    with fiona.open(vector_output, 'w', 'ESRI Shapefile', shp_schema, crs) as shp:
        for pixel_value in unique_values:
            polygons = [shape(geom) for geom, value in shapes
                        if value == pixel_value]
            multipolygon = MultiPolygon(polygons)
            shp.write({
                'geometry': mapping(multipolygon),
                'properties': {'pixelvalue': int(pixel_value)}
            })

    return "All done!"


os.chdir("/pine/scr/a/c/acgold")

# Setup for Longleaf
mask = rio.open_rasterio("output/osm/ways/buffered_osm_ways.tif", chunks=True, lock=False)
# mask.rio.set_nodata(0, inplace = True)
# mask = mask.astype("int16")

# masked_raster = mask.where(mask != mask.rio.nodata)
# mask.rio.write_nodata(mask, encoded = True, inplace = True)

# with ProgressBar():
#         masked_raster.rio.to_raster(raster_output, dtype= "int16", windowed=True, lock=threading.Lock(), tiled = True, compress='lzw', BIGTIFF="YES") 
# # Setup for local testing
# mask = rio.open_rasterio("/Users/adam/Downloads/buffered_osm_ways.tif", chunks = True, lock = False)

# Iterate over water levels
water_levels = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0] 
water_level_labels = ["zero_to_point1", "zero_to_point2", "zero_to_point3", "zero_to_point4", "zero_to_point5", "zero_to_point6", "zero_to_point7", "zero_to_point8", "zero_to_point9", "zero_to_1"] #

for index, value in enumerate(water_levels):
    x = rio.open_rasterio(Path("xarray_output/output/model_results", water_level_labels[index], "error_class.tif"), chunks=True, lock=False)
    raster_output = Path("xarray_output/output/model_results", water_level_labels[index], "htf_on_rds.tif")
    vector_output = Path("xarray_output/output/model_results", water_level_labels[index], "htf_on_rds.shp")
    
    make_intersecting_polygons(x = x, mask = mask, raster_output = raster_output, vector_output = vector_output)