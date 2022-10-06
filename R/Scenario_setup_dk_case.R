#### Setting OM parameters

### Scenario DK: Only Western Baltic
Sim1 <- list(

  ### Number of simulation years (time step is a month)
  n_years = 15,

  ### Habitat (depth) parameters. Very important as it controls how species are distributed in space, thus affects both
  ### the population dynamics and the vessel dynamics
  Range_X = 1:40,           # the x-axis extent. the bigger, the more complex topography you can get at the cost of simulation time
  Range_Y = 1:40,           # the y-axis extent. the bigger, the more complex topography you can get at the cost of simulation time
  SD_O = 100,						    # SD of depth observation in space. the bigger, the more variable is the depth
  SpatialScale = 3,					# the spatial correlation range. The bigger, the more correlated are depth in space (patchy if small). N.B: Absolute value of high/low depends on the extent of x-axis and y-axis
  year.depth.restriction = 1000,	# If MPA, then years when MPA implemented (default > n_years)
  # depth.restriction = c(50,150),	# location of MPA

  ### Species parameters
  n_species  = 7, ## Alcidae, S. mollissima, Porpoise, cod, plaice, lumpsucker, turbot
  ## Note that for cod, the differences between the stocks are important to take
  ## into account, so it might be preferable to limit the study area to e.g., the
  ## Western Baltic (incl. Kattegat)
  price_fish = matrix(rep(c(-1,-1,-50,25,10,40,40),15), ncol=7, byrow=T),   # random

  ## Fish habitat preference/movement control parameters
  func_mvt_dist = c("Exp", "Exp", "Exp", "Exp", "Exp", "Exp", "Exp"),					# shape of mvt p_function
  func_mvt_depth = c("Lognorm", "Lognorm", "Lognorm", "Lognorm","Lognorm",  "Lognorm", "Lognorm"),	# shape of depth preference p_function (choice of Normal, Exp, Lognormal, Uniform)
  func_mvt_lat = c("Unif", "Unif", "Unif", "Unif", "Unif", "Unif", "Unif"),					# shape of range preference p_function (choice of Normal, Exp, Lognormal, Uniform)

  Fish_dist_par1 =  matrix(c(3,1,4,2,2,1,2, # mvt distance mean - their mobility within month1 only values >0
                             3,1,4,2,2,1,2, # month2   only values >0
                             3,1,4,2,2,1,2, # month3   only values >0
                             2,30,4,2,2,5,2, # month4   only values >0
                             1,30,2,2,2,10,2, # month5   only values >0
                             1,30,2,2,2,10,2, # month6   only values >0
                             1,30,2,2,2,10,2, # month7   only values >0
                             1,1,2,2,2,10,2, # month8   only values >0
                             2,1,2,2,2,10,2, # month9   only values >0
                             3,10,4,2,2,10,2, # month10  only values >0
                             3,5,4,2,2,5,2, # month11  only values >0
                             3,3,4,2,2,1,2),# month12  only values >0
                           nrow=12, ncol=7, byrow=T),
  Fish_depth_par1 = matrix(c(25, 5, 20, 20, 20, 50, 100,  # depth preference mean per month 1
                             25, 5, 20, 20, 20, 30, 100,   # month2
                             25, 5, 20, 20, 20, 10, 100,   # month3
                             25, 5, 20, 20, 30, 10, 30,   # month4
                             25, 5, 20, 20, 35, 30, 20,    # month5
                             25, 5, 20, 20, 40, 50, 20,    # month6
                             25, 5, 20, 20, 40, 60, 20,    # month7
                             25, 5, 20, 20, 40, 100, 30,   # month8
                             25, 5, 20, 20, 30, 100, 100,  # month9
                             25, 5, 20, 20, 25, 100, 100,  # month10
                             25, 5, 20, 20, 20, 100, 100,  # month11
                             25, 5, 20, 20, 20, 50, 100),  # month12
                           nrow=12, ncol=7, byrow=T),
  ## Check the Excel sheet to update the values (note that it's SD(log()))
  Fish_depth_par2 = matrix(c(2, 0.5, 1, 1, 0.5, 0.5, 1,# depth preference sd log scale per month 1
                             2, 0.5, 1, 1, 0.5, 0.5, 1,# month2
                             2, 0.5, 1, 1, 0.5, 0.5, 1,# month3
                             2, 0.5, 1, 1, 0.5, 0.5, 1,# month4
                             2, 0.5, 1, 1, 0.5, 0.5, 1,# month5
                             2, 0.5, 1, 1, 0.5, 0.5, 1,# month6
                             2, 0.5, 1, 1, 0.5, 0.5, 1,# month7
                             2, 0.5, 1, 1, 0.5, 0.5, 1,# month8
                             2, 0.5, 1, 1, 0.5, 0.5, 1,# month9
                             2, 0.5, 1, 1, 0.5, 0.5, 1,# month10
                             2, 0.5, 1, 1, 0.5, 0.5, 1,# month11
                             2, 0.5, 1, 1, 0.5, 0.5, 1),# month12
                           nrow=12, ncol=7, byrow=T),

  Rangeshift_proportion = matrix(c(0, 0, 0, 0, 0, 0.25, 0,# how much (proportion) of the population leave the fishing area by season. 0=nothing, 1=all
                                   0, 0, 0, 0, 0, 0, 0,# month2
                                   0, 0, 0, 0, 0, 0, 0,# month3
                                   0.5, 0.5, 0, 0, 0, 0.25, 0,# month4
                                   0.95, 0.95, 0, 0, 0, 0.5, 0,# month5
                                   0.95, 0.95, 0, 0, 0, 1, 0,# month6
                                   0.95, 0.95, 0, 0, 0, 1, 0,# month7
                                   0.7, 0.7, 0, 0, 0, 1, 0,# month8
                                   0.5, 0.5, 0, 0, 0, 1, 0,# month9
                                   0, 0, 0, 0, 0, 1, 0,# month10
                                   0, 0, 0, 0, 0, 0.5, 0,# month11
                                   0, 0, 0,0, 0, 0.25, 0),# month12          # the proportion of the population that leave the fishing groun X axis range max
                                 nrow=12, ncol=7, byrow=T),                    #
  Rangeshift_distance = c(40,50,10,0,0,50,10),   # 0 if the species does not perform any range shift

  ## Species Schaefer pop dyn parameters
  B0 = c(76500,333500,100000,23492000,230000000,100000,4163000)*1000,	# based on values in XL
  r = c(0.06622516556, 0.111111111, 0.1333333333, 0.07407407407, 0.2222222222, 0.2857142857, 0.1785714286)/12,     # based on values in XL
  sigma_p= c(0.65, 0.4, 0.4, 0.89, 0.4, 0.4, 0.4),           # based on values in XL
  sigma_p_timing= c(4,5,7,1,3,2,7),                        # based on values in XL
  fish.mvt = TRUE,				                        # whether animals redistribute annually based on habitat preference

  ### Parameters controlling the vessel dynamics
  Nregion = c(2,2),         # nb of fishing regions for the fishermen (equal cut of grid along X and Y)
  Nvessels = 50,					  # nb vessels
  Tot_effort = 2000,				# end year nb of effort
  CV_effort = 0.2, 					# CV of effort around the yearly mean effort
  qq_original = c(0.05,0.025,0.05,0.2,0.2,0.05,0.05),			  # the average catchability coef by species for ALL vessels (does not mean anything. just a scaler)
  catch_trunc = c(1, 1, 1, 1, 0,0,0,0),			  # truncate value if 1 otherwise keep continuous
  CV_vessel = 0.0001,					# the between vessel variability in mean catchability
  vessel_seeds = 10,        # this creates heterogeneity in the sampled vessels
  Effort_alloc_month = c(5,4,3,2,1,1,1,2,3,4,5,5),  # it is rescaled to sum to 1
  do.tweedie = TRUE,				# include observation error in vessel catchability
  # xi = c(1.7,1.7,1.2,1.5,1.7,1.7,1.2,1.5),  # power of the tweedie distribution. reduce this to have more 0s. ==0 or >0
  xi = c(1.9,1.9,1.9,1.9,1.9,1.9,1.9),  # power of the tweedie distribution. reduce this to have more 0s. ==0 or >0
  # phi = c(0.2,0.2,0.2,0.2), # the scaler of the tweedie distribution
  phi = c(0.5,0.5,0.5,0.5,0.5,0.5,0.5), # the scaler of the tweedie distribution
  Preference = 1, 					# controls how effort concentrate into areas. The higher, the more concentrated is the effort
  Changing_preference = FALSE, 		# whether effort concentration changes over time


  ### Parameter controlling the resampling procedure from the whole fleet
  samp_prob = 0.2,             # this is the sampling probability
  samp_unit = "vessel",        # the samping unit: "vessel" or "fishing" (i.e. random sample from all fishing events)
  samp_seed = 123,             # the seed for reproducibility of the samples taken
  samp_mincutoff = 0,        # cut-off value to round values to 0
  start_year = 5,

  ### Other OM control features
  plotting = TRUE,
  parallel = FALSE,
  Interactive = TRUE
)
