from pyrosm import OSM

osm = OSM("/Volumes/my_hd/osrm/nc_osrm/north-carolina-latest.osm.pbf")

# This will read the drivable network. We are interested in getting drivable roads as a gpkg that we can then filter out bridges/tunnels and road that intersects NHD waterbodies
roads = osm.get_network(network_type="driving")

# write our roadways with the source nodes to file so we can do processing in QGIS or ArcGIS
roads.to_file("/Volumes/my_hd/osrm/nc_osm_drivable_roads.gpkg", layer="nc_osm_drivable_roads", driver="GPKG")


