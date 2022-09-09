library(sf)
library(tidyverse)

road_segments <- sf::st_read("/Users/adam/Downloads/osm_edges.gpkg")

# This will be in a loop
htf_polygons <- sf::st_read("/Users/adam/Downloads/htf_on_rds_int.gpkg")


classify_road_flooding <- function(road_segments, htf_polygons){
  roads_affected <- unique(htf_polygons$id)
  
  filtered_road_segments <- road_segments |> 
    dplyr::select(lanes, highway, id, u, v, geom) |> 
    filter(id %in% roads_affected)
  
  filtered_road_segments$lanes = as.numeric(filtered_road_segments$lanes)
  filtered_road_segments$lanes[is.na(filtered_road_segments$lanes)] <- 2
  filtered_road_segments$buffer_distance <- filtered_road_segments$lanes * 2.5
  
  filtered_road_segments <- filtered_road_segments |> 
    mutate(new_id = paste(id, u, v, sep= "_"))
  
  buffered_filtered_road_segments <- sf::st_buffer(x = filtered_road_segments, dist = filtered_road_segments$buffer_distance)
  
  impacted_buffered_road_segments <- buffered_filtered_road_segments[htf_polygons,]
  
  impacted_road_segments <- filtered_road_segments |> 
    filter(new_id %in% impacted_buffered_road_segments$new_id)
  
  hc_polygons <- htf_polygons |> 
    filter(DN == 1)
  
  lc_polygons <- htf_polygons |> 
    filter(DN == 0)
  p <- progressr::progressor()
  
  roads_with_impact_class <- foreach(i = 1:100, .combine = "bind_rows") %do%{ #nrow(impacted_road_segments)
    p()
    # Select a row and buffered row
    row <- impacted_road_segments[i,]
    buff_row <- impacted_buffered_road_segments[i,]
    
    # calculate slope
    line_end_coords <- sf::st_coordinates(row)
    line_diff <- diff(line_end_coords)[1:2]
    slope <- -1/(line_diff[2] / line_diff[1])
    
    # Break line up into little parts
    segmented_line <- sf::st_segmentize(row, dfMaxLength = 2) |> 
      sf::st_cast("POINT")
    
    # Get the perpendicular lines from the road segment
    perp_lines <- foreach(j = 1:nrow(segmented_line), .combine = "bind_rows") %do% {
      z <- segmented_line[j,]
      
      z_coords <- sf::st_coordinates(z)
      
      x_diff <- z$buffer_distance / sqrt((slope ^ 2) + 1)
      
      sf::st_geometry(z) <- sf::st_sfc(sf::st_linestring(matrix(c(z_coords[1] + x_diff, z_coords[1] - x_diff, z_coords[2] + (x_diff * slope), z_coords[2] - (x_diff * slope)), nrow = 2)), crs = row |> sf::st_crs())
      
      z
    }
    
    # Select high-confidence and low-confidence polygons that intersect the buffered roadway
    hc_polygons_selected <- hc_polygons[buff_row,]|> 
      sf::st_union() 
    
    lc_polygons_selected <- lc_polygons[buff_row,] |> 
      sf::st_union()
    
    # Calculate the length of the line. This should be 2 * buffer_distance
    perp_lines <- perp_lines |> 
      mutate(length = sf::st_length(perp_lines))
    
    # Measure length of perpendicular line with HIGH-confidence htf erased. How much road is not covered
    if(length(hc_polygons_selected) > 0){
      perp_lines <- perp_lines |> 
        mutate(hc_length = sf::st_length(sf::st_difference(perp_lines, hc_polygons_selected)))
    }
    if(length(hc_polygons_selected) == 0){
      perp_lines <- perp_lines |> 
        mutate(hc_length = length)
    }
    
    # Measure length of perpendicular line with LOW-confidence htf erased. How much road is not covered
    if(length(lc_polygons_selected) > 0){
      perp_lines <- perp_lines |> 
        mutate(lc_length = sf::st_length(sf::st_difference(perp_lines, lc_polygons_selected)))
    }
    if(length(lc_polygons_selected) == 0){
      perp_lines <- perp_lines |> 
        mutate(lc_length = length)
    }
    
    perp_lines <- perp_lines |> 
      mutate(hc_percent_covered = 100 - (units::drop_units(hc_length/length) * 100),
             lc_percent_covered = 100 - (units::drop_units(lc_length/length) * 100),
             min_percent_covered = hc_percent_covered,
             max_percent_covered = hc_percent_covered + lc_percent_covered)
    
    
    n_min_75_100 = sum(perp_lines$min_percent_covered >= 75)
    n_min_50_75 = sum(perp_lines$min_percent_covered >= 50 & perp_lines$min_percent_covered < 75)
    n_min_25_50 = sum(perp_lines$min_percent_covered >= 25 & perp_lines$min_percent_covered < 50)
    n_min_0_25 = sum(perp_lines$min_percent_covered > 0 & perp_lines$min_percent_covered < 25)
    n_min_0 = sum(perp_lines$min_percent_covered == 0.0)
    
    n_max_75_100 = sum(perp_lines$max_percent_covered >= 75)
    n_max_50_75 = sum(perp_lines$max_percent_covered >= 50 & perp_lines$max_percent_covered < 75)
    n_max_25_50 = sum(perp_lines$max_percent_covered >= 25 & perp_lines$max_percent_covered < 50)
    n_max_0_25 = sum(perp_lines$max_percent_covered > 0 & perp_lines$max_percent_covered < 25)
    n_max_0 = sum(perp_lines$max_percent_covered == 0.0)
    
    # Impact class: 3 = 75-100% coverage of HTF on road, 2 = 50 - 75%, 1 = 25 - 50%, 0 = 0 - 25%
    min_impact_class = ifelse(n_min_75_100 > 2, 3, 
                               ifelse(n_min_50_75 > 2, 2,
                                      ifelse(n_min_25_50 > 2, 1, 0)))
    
    max_impact_class = ifelse(n_max_75_100 > 2, 3, 
                               ifelse(n_max_50_75 > 2, 2,
                                      ifelse(n_max_25_50 > 2, 1, 0)))
    
    row <- row |> 
      mutate(min_impact_class = min_impact_class,
             n_min_75_100 = n_min_75_100,
             n_min_50_75 = n_min_50_75,
             n_min_25_50 = n_min_25_50,
             n_min_0_25 = n_min_0_25,
             n_min_0 = n_min_0,
             max_impact_class = max_impact_class,
             n_max_75_100 = n_max_75_100,
             n_max_50_75 = n_max_50_75,
             n_max_25_50 = n_max_25_50,
             n_max_0_25 = n_max_0_25,
             n_max_0 = n_max_0)
    
    row
  }

  return(roads_with_impact_class)
  
}
