from pyrosm import OSM

osm = OSM("/Volumes/my_hd/osrm/nc_osrm/north-carolina-latest.osm.pbf")

# This will read the drivable network. We are interested in getting drivable roads as a gpkg that we can then filter out bridges/tunnels and road that intersects NHD waterbodies
roads = osm.get_network(network_type="driving", extra_attributes="lanes")

# nodes, roads = osm.get_network(nodes=True, network_type="driving", extra_attributes="lanes")

# write our roadways with the source nodes to file so we can do processing in QGIS or ArcGIS
roads.to_file("/Volumes/my_hd/osrm/nc_osm_drivable_roads.gpkg", layer="nc_osm_drivable_roads", driver="GPKG")

import geopandas as gpd
import pyarrow.parquet

roads_unprojected = gpd.read_file("/Volumes/my_hd/osrm/nc_road_lines_w_nodes.gpkg")
test_roads = roads_unprojected.head(n=100).copy()
test_roads_proj = test_roads.to_crs(epsg=32617)


roads_projected = roads_unprojected.to_crs(epsg=32617)

roads_projected.to_parquet("/Volumes/my_hd/osrm/nc_road_lines_w_nodes_proj.parquet")
roads_projected.to_file("/Volumes/my_hd/osrm/nc_road_lines_w_nodes_proj.gpkg", layer = "data", driver = "GPKG")


