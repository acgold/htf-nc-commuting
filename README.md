# About

High tide flooding (HTF) is a less-extreme but more frequent type of flooding that is increasingly impacting coastal areas. This chronic flooding can have negative impacts on infrastructure and people, especially through road closures. 

Previous analyses focused on HTF and commutes have used low-resolution data from national sources to estimate the location and depth of these floodwaters, but the resolution of floodwater extent data is important in low-slope areas such as coastal North Carolina, USA. Additionally, most analyses rely on floodwater depth to estimate how road speeds will be reduced during flooding, but this approach does not capture flooding that covers some or most of the roadway and would likely cause roadway speed reductions.

This analysis circumvents these previous limitations by using high-resolution elevation data (1-meter) to model a range of water levels within the HTF range. Paired with concurrent OpenStreetMap road network data, these higher resolution data produce more precise impact estimates and allow for the production of confidence intervals. We then use LODES commute data and Census block data to determine characteristics of people whose commutes are impacted by various levels of HTF.

# Methods

The steps of this analysis are:

1. Parse and process OpenStreetMap data (*osm_processing.jl*). This creates individual road segments (lines with only start node -> end node), lines of full roadways (by 'way_id'), buffers full roadway lines by the number of lanes * 2.5 meters.
2. Model water levels from 0 to 1 meter at 0.1 meter increments (*raster_math.R* - not on here yet). The end product here is a raster denoting areas that are inundated at a particular water level, and the value of raster indicates if the area is 'high' or 'low' confidence.
3. Use ArcGIS pro model ('get_htf_on_roads') to convert htf rasters to polygons, dissolve them by confidence type, then intersect them with buffered roads.
4. Back to Julia to determine impact of HTF on individual road segments (*htf_impact_analysis.jl*). We determine for each road segment how much of the road width is covered by modeled inundation. This allows us to modify the speed of individual road segments.
5. We spin up the [Open Source Routing Machine](http://project-osrm.org) in a docker container and use julia to get routes for each commute in NC both with and without the impacts of various water levels (file not on here yet).
