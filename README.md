# About

High tide flooding (HTF) is a less-extreme but more frequent type of flooding that is increasingly impacting coastal areas. This chronic flooding can have negative impacts on infrastructure and people, especially through road closures. 

Most analyses of flooding and commutes have used low-resolution data over large areas to estimate the location and depth of floodwaters, but the resolution of floodwater extent data is important. In low-slope areas such as coastal North Carolina USA, small differences in water level can have large differences in the area of inundation. Additionally, most analyses rely on floodwater depth to estimate how road speeds will be reduced during flooding, but this approach does not capture flooding that covers some or most of the roadway and would likely cause roadway speed reductions. In summary, low-resolution data used to estimate impacts of HTF likely does not capture important nuances in impact.

This analysis circumvents these previous limitations by using high-resolution elevation data (1-meter) to model a range of water levels within the HTF range. Paired with concurrent OpenStreetMap road network data, these higher resolution data produce more precise impact estimates and allow for the production of confidence intervals. We then use LODES commute data and Census block data to determine characteristics of people whose commutes are impacted by various levels of HTF.

# Methods

This analysis makes use of publicly available road ([OpenStreetMap](https://www.openstreetmap.org/#map=4/38.01/-95.84)), commute ([LEHD LODES](https://lehd.ces.census.gov/data/)),  [census block](https://walker-data.com/tidycensus/), and elevation data ([NOAA CoNED Topobathy](https://www.fisheries.noaa.gov/inport/item/67013)).

We use `Julia`, `R`, and ArcGIS Pro for different steps of processing and analysis. Effort was made to use Julia as much as possible to maximize efficiency, but `R` ([`Terra`](https://rspatial.org/terra/pkg/index.html) package) is used for water level modelling and ArcGIS Pro is used for raster -> polygon conversion and finding the intersection between HTF and roadways.

The steps of this analysis are:

1. Parse and process OpenStreetMap data ([**osm_processing.jl**](https://github.com/acgold/htf-nc-commuting/blob/main/osm_processing.jl)). This creates individual road segments (lines with only start node -> end node), lines of full roadways (by 'way_id'), buffers full roadway lines by the number of lanes * 2.5 meters.
2. Model water levels from 0 to 1 meter at 0.1 meter increments ([**water_level_modelling.R**](https://github.com/acgold/htf-nc-commuting/blob/main/water_level_modelling.R)). The end product here is a raster denoting areas that are inundated at a particular water level, and the value of raster indicates if the area is 'high' or 'low' confidence.
3. Use ArcGIS pro model ('get_htf_on_roads') to convert htf rasters to polygons, dissolve them by confidence type, then intersect them with buffered roads.
4. Back to Julia to determine impact of HTF on individual road segments ([**htf_impact_analysis.jl**](https://github.com/acgold/htf-nc-commuting/blob/main/htf_impact_analysis.jl)). We determine for each road segment how much of the road width is covered by modeled inundation. This allows us to modify the speed of individual road segments.
5. Using some nice packages in R (Tidycensus and lehdr), we download LODES data (commuting) and census block data (spatial + demographic info) and process them to be used for routing (**[lodes_and_census_processing.R](https://github.com/acgold/htf-nc-commuting/blob/main/lodes_and_census_processing.R)**).
5. We spin up the [Open Source Routing Machine](http://project-osrm.org) in a docker container and use julia to get routes for each commute in NC both with and without the impacts of various water levels ([**osrm_routing.jl**](https://github.com/acgold/htf-nc-commuting/blob/main/osrm_routing.jl)).
