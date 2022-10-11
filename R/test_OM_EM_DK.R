############################################################################################################
### Case Study: EM data
### Spatial explicit operating model for modeling fishery and species "monitoring"
###
### The most important part is to define the fish abundance, price, and habitat
### overlap --> need to make it more explicit
### --> because this will create the basis for trade-offs and targeting change
### think about changing correlation by year (or random effect / random walk for
### the cor par)
### streamline with furrr the run of scenario & models
### Make more documentation as in sdmTMB

############################################################################################################

# rm(list=ls())
gc()

#### Loading libraries
pacman::p_load(parallel, MASS, RandomFields, fields, geoR, gtools, tweedie,
               ggplot2, tidyverse, ggnewscale, TMB, TMBhelper, sdmTMB)


#### sourcing codes
source("R/Generate_scenario_data.r")
source("R/Functions.R")

#### Setting OM parameters

### Scenario 1:
Sim1 <- list(

  ### Number of simulation years (time step is month)
  n_years = 15,

  ### Habitat (depth) parameters. Very important as it controls how species are
  ### distributed in space, thus affects both the population dynamics and the
  ### vessel dynamics
  Range_X = 1:40,           # the x-axis extent. the bigger, the more complex topography you can get at the cost of simulation time
  Range_Y = 1:40,           # the y-axis extent. the bigger, the more complex topography you can get at the cost of simulation time
  SD_O = 100,						    # SD of depth observation in space. the bigger, the more variable is the depth
  SpatialScale = 3,					# the spatial correlation range. The bigger, the more correlated are depth in space (patchy if small). N.B: Absolute value of high/low depends on the extent of x-axis and y-axis
  year.depth.restriction = 1000,	# If MPA, then years when MPA implemented (default > n_years)
  # depth.restriction = c(50,150),	# location of MPA

  ### Species parameters
  n_species  = 8, ## Alcidae, Anatidae, Gavidae, Porpoise, cod, plaice, lumpsucker, turbot
  ## Note that for cod, the differences between the stocks are important to take
  ## into account, so it might be preferable to limit the study area to e.g., the
  ## Western Baltic (incl. Kattegat)
  price_fish = matrix(rep(c(-1,-1,-1,-50,25,10,40,40),15), ncol=8, byrow=T),   # random

  ## Fish habitat preference/movement control parameters
  func_mvt_dist = c("Exp", "Exp", "Exp", "Exp", "Exp", "Exp", "Exp", "Exp"),					# shape of mvt p_function
  func_mvt_depth = c("Lognorm", "Lognorm", "Lognorm", "Lognorm","Lognorm", "Lognorm", "Lognorm", "Lognorm"),	# shape of depth preference p_function (choice of Normal, Exp, Lognormal, Uniform)
  func_mvt_lat = c("Unif", "Unif", "Unif", "Unif", "Unif", "Unif", "Unif", "Unif"),					# shape of range preference p_function (choice of Normal, Exp, Lognormal, Uniform)

  Fish_dist_par1 = c(rep(0, 8), 3),							# mvt distance mean - their mobility within time step
  Fish_dist_par2 = rep(0, 8), 										# mvt distance (not used)
  Fish_depth_par1 = matrix(c(40, 10, 10, 30, 20, 30, 50, 100,  # depth preference mean per month 1
                             40, 10, 10, 30, 20, 30, 30, 100,   # month2
                             40, 10, 10, 30, 20, 30, 20, 100,   # month3
                             40, 10, 10, 30, 20, 30, 20, 100,   # month4
                             40, 10, 10, 30, 20, 30, 30, 30,    # month5
                             40, 10, 10, 30, 20, 30, 50, 30,    # month6
                             40, 10, 10, 30, 20, 30, 60, 30,    # month7
                             40, 10, 10, 30, 20, 30, 100, 40,   # month8
                             40, 10, 10, 30, 20, 30, 100, 100,  # month9
                             40, 10, 10, 30, 20, 30, 100, 100,  # month10
                             40, 10, 10, 30, 20, 30, 100, 100,  # month11
                             40, 10, 10, 30, 20, 30, 50, 100),  # month12
                           nrow=12, ncol=8, byrow=T),
  ## Check the Excel sheet to update the values (note that it's SD(log()))
  Fish_depth_par2 = matrix(c(1, 0.5, 0.5, 1, 1, 0.5, 0.5, 1,# depth preference sd log scale per month 1
                             1, 0.5, 0.5, 1, 1, 0.5, 0.5, 1,# month2
                             1, 0.5, 0.5, 1, 1, 0.5, 0.5, 1,# month3
                             1, 0.5, 0.5, 1, 1, 0.5, 0.5, 1,# month4
                             1, 0.5, 0.5, 1, 1, 0.5, 0.5, 1,# month5
                             1, 0.5, 0.5, 1, 1, 0.5, 0.5, 1,# month6
                             1, 0.5, 0.5, 1, 1, 0.5, 0.5, 1,# month7
                             1, 0.5, 0.5, 1, 1, 0.5, 0.5, 1,# month8
                             1, 0.5, 0.5, 1, 1, 0.5, 0.5, 1,# month9
                             1, 0.5, 0.5, 1, 1, 0.5, 0.5, 1,# month10
                             1, 0.5, 0.5, 1, 1, 0.5, 0.5, 1,# month11
                             1, 0.5, 0.5, 1, 1, 0.5, 0.5, 1),# month12
                           nrow=12, ncol=8, byrow=T),
  Fish_range_par1 = rep(0, 8),                    # X-axis range min
  Fish_range_par2 = rep(50,8),                    # X axis range max

  ## Species Schaefer pop dyn parameters
  B0 = c(10000,10000,10000,10000,10000,10000,10000,10000)*1000,	# based on values in XL
  r = c(0.22, 0.17, 0.08, 0.15, 0.22, 0.17, 0.08, 0.15)/12,     # based on values in XL
  sigma_p= c(0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4),           # based on values in XL
  sigma_p_timing= c(1,3,3,4,9, 9, 8, 9),                        # based on values in XL
  fish.mvt = TRUE,				                        # whether animals redistribute annually based on habitat preference

  ### Parameters controlling the vessel dynamics
  Nregion = c(2,2),         # nb of fishing regions for the fishermen (equal cut of grid along X and Y)
  Nvessels = 300,					  # nb vessels
  Tot_effort = 2000,				# end year nb of effort
  CV_effort = 0.2, 					# CV of effort around the yearly mean effort
  qq_original = c(0.05,0.025,1e-5,0.05,0.2,0.2,0.05,0.05),			  # the average catchability coef by species for ALL vessels (does not mean anything. just a scaler)
  catch_trunc = c(1,1,1,1,0,0,0,0),			  # truncate value if 1 otherwise keep continuous
  CV_vessel = 0.0001,				# the between vessel variability in mean catchability
  vessel_seeds = 10,        # this creates heterogeneity in the sampled vessels
  Effort_alloc_month = c(5,4,3,2,1,1,1,2,3,4,5,5),  # it is rescaled to sum to 1
  do.tweedie = TRUE,				# include observation error in vessel catchability
  # xi = c(1.7,1.7,1.2,1.5),  # power of the tweedie distribution. reduce this to have more 0s. ==0 or >0
  xi = c(1.9,1.9,1.9,1.9,1.9,1.9,1.9,1.9),  # power of the tweedie distribution. reduce this to have more 0s. ==0 or >0
  # phi = c(0.2,0.2,0.2,0.2), # the scaler of the tweedie distribution
  phi = c(0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5), # the scaler of the tweedie distribution
  Preference = 1, 					# controls how effort concentrate into areas. The higher, the more concentrated is the effort
  Changing_preference = FALSE, 		# whether effort concentration changes over time


  ### Parameter controlling the resampling procedure from the whole fleet
  samp_prob = 0.2,             # this is the sampling probability
  samp_unit = "vessel",        # the sampling unit: "vessel" or "fishing" (i.e. random sample from all fishing events)
  samp_seed = 123,             # the seed for reproducibility of the samples taken
  samp_mincutoff = 0,        # cut-off value to round values to 0
  start_year = 5,

  ### Other OM control features
  plotting = TRUE,
  parallel = FALSE,
  Interactive = FALSE
)
