library(terra)

#----------- Overview ----------------------
# This file creates modeled:
# - Water level surface elevations
# - Water depth surfaces
# - Error surfaces
# - Classified error surfaces

# To do this, we will:
# 1. Use a conversion factor between NAVD88 and MHHW to 
# make a NOAA DEM referenced to tidal datum
# 
# 2. Using a custom function, model areal extent of inundation
# at water levels from 0 to 1 m MHHW at 0.1 m increments

#---------------- Converting DEM to MHHW -------------------

# Load large, unmodified NOAA DEM for NC. 1-meter horizontal resolution
original_dem <- terra::rast("/Volumes/my_hd/htf_on_roads/noaa_elevation/North_Carolina_CoNED_Topobathy_DEM_1m.tif")

# Load original resolution MHHW conversion, much coarser resolution
original_MHHW_conversion <- terra::rast("/Volumes/my_hd/htf_on_roads/NOAA_OCM_MHHWInterpolatedSurface/nc_mhhw_navd88_proj.tif") |>
  terra::project(crs(original_dem))

# Resammple MHHW conversion raster to original DEM's resolution
original_MHHW_conversion |>
  terra::resample(y=original_dem, method = "near", filename="/Volumes/my_hd/htf_on_roads/NOAA_OCM_MHHWInterpolatedSurface/terra_resamp_mhhw_conv.tif")

# read back in the resampled conversion raster
resampled_MHHW_conversion <- terra::rast("/Volumes/my_hd/htf_on_roads/NOAA_OCM_MHHWInterpolatedSurface/terra_resamp_mhhw_conv.tif")

# Combine the original DEM and matching resolution conversion raster
dem_and_conversion <- c(original_dem, resampled_MHHW_conversion)

# Convert the original DEM to the MHHW datum using the resampled conversion raster
# could use overlay with the following function and it might be faster
new_dem <- lapp(dem_and_conversion,fun=function(x,y){return(x-y)},
                overwrite = T,
                filename = "/Volumes/my_hd/htf_on_roads/noaa_elevation/terra_noaa_mhhw_dem_1m.tif")

#--------------- Reducing raster sizes ------------------
# # This clipping code is just for testing purposes.
# sample_extent <- terra::vect("/Users/adam/Downloads/carteret_boundary.gpkg")
# 
# clipped_dem <- terra::crop(mini_dem, ext(sample_extent |> 
#                                            terra::project(terra::crs(mini_dem))),
#                            overwrite=T,
#                            filename="/Volumes/my_hd/htf_on_roads/noaa_elevation/carteret_test_dem.tif")
# 
# clipped_dem <- terra::rast("/Volumes/my_hd/htf_on_roads/noaa_elevation/carteret_test_dem.tif")

# Filter out elevations that we know we will not need to decrease raster size.
# This only keeps values from 0 to 5 m MHHW. We will read this raster in later
terra::clamp(
  mhhw_dem,
  lower = 0,
  upper = 5,
  values = F,
  overwrite = T,
  filename = "/Volumes/my_hd/htf_on_roads/noaa_elevation/terra_noaa_zero_to_5m.tif"
)

#------------------ Modelling function ----------------------
create_water_surfaces <- function(max_wl, min_wl = 0, dem, overwrite=F, directory){
  if(!dir.exists(directory)){
    dir.create(directory)
  }
  
  # These are the errors associated with the input rasters
  dem_rmse = 35 #cm
  conv_rmse = 10 #cm
  muc = sqrt(dem_rmse^2 + conv_rmse^2)/100 # in meters. About 0.364
  
  cat("* Modelling water level between", min_wl, "and", max_wl, "meters","\n")
  cat("(1/4) extracting land DEM....", "\n")
  
  # We will select the raster values that are above our min_wl (zero) and below our upper_wl (the value that has a 20% chance of impact)
  land_dem <- terra::clamp(dem, 
                           lower=min_wl,
                           upper= max_wl - (qnorm(0.2)*muc),
                           values=F,
                           overwrite = T,
                           filename = file.path(directory, "impacted_land_dem.tif"))
  
  m <- c(min_wl, max_wl, max_wl)
  rclmat <- matrix(m, ncol=3, byrow=TRUE)
  
  # # This creates a water surface raster, but we want to know uncertainty,
  # # so we are using a raster created later. Keeping this code for now.
  # water_surface <- terra::classify(land_dem,
  #                                  rcl = rclmat,
  #                                  others = NA,
  #                                  right = T,
  #                                  overwrite = overwrite,
  #                                  filename = file.path(directory, "water_surface.tif"))
  
  cat("(2/4) calculating water depth....", "\n")
  
  water_depth <- terra::app(land_dem,
                            fun = function(x){
                              return(max_wl - x)
                            },
                            overwrite = overwrite,
                            filename = file.path(directory,"water_depth.tif"))
  
  # Methods from Schmid et al., 2014 - https://doi.org/10.2112/JCOASTRES-D-13-00118.1
  cat("(3/4) calculating inundation error....", "\n")
  DEM_error_rast <- terra::app(land_dem,
                               fun = function(x){
                                 return(pnorm((max_wl - x)/muc))
                               },
                               overwrite = overwrite,
                               filename = file.path(directory,"error.tif"))
  
  m_error <- c(0.5, 0.8, 0,
               0.8, 1.0, 1)
  rclmat_error <- matrix(m_error, ncol=3, byrow=TRUE)
  
  # Classify low- and high-confidence error classes. 
  # Low is 50 - 80% and high is greater than 80% likelihood of inundation.
  # Not using anything less than 50%
  
  cat("(4/4) classifying error classes....", "\n")
  error_surface <- terra::classify(DEM_error_rast,
                                   rcl = rclmat_error,
                                   others = NA,
                                   right = NA,
                                   overwrite = overwrite,
                                   filename = file.path(directory, "class_error.tif"),
                                   datatype = 'INT4U')
}

#-------------------- Loop for modelling --------------------

time <- Sys.time()

mhhw_dem <- terra::rast("/Volumes/my_hd/htf_on_roads/noaa_elevation/terra_noaa_mhhw_dem_1m.tif")
mini_dem <- terra::rast("/Volumes/my_hd/htf_on_roads/noaa_elevation/terra_noaa_zero_to_5m.tif")

# # make water level below zero m to get permanent water surface
# create_water_surfaces(dem = mhhw_dem,
#                       max_wl = 0,
#                       min_wl = -100,
#                       overwrite=T,
#                       directory = "/Volumes/my_hd/htf_on_roads/noaa_elevation/water_level_modelling/below_zero")

# max water levels
water_levels <- c(0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0)
water_level_labels <- c("zero_to_point1", "zero_to_point2", "zero_to_point3", "zero_to_point4", "zero_to_point5", "zero_to_point6", "zero_to_point7", "zero_to_point8", "zero_to_point9", "zero_to_1")

for(i in 1:length(water_levels)){
  create_water_surfaces(dem = mini_dem,
                        max_wl = water_levels[i],
                        min_wl = 0,
                        overwrite=T,
                        directory = file.path("/Volumes/my_hd/htf_on_roads/noaa_elevation/water_level_modelling",water_level_labels[i]))
}

Sys.time() - time

