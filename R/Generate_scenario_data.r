
## Main function to generate data (the OM)
Generate_scenario_data <- function(Sim_Settings,
                                   seed_input = 123,
                                   parallel = FALSE){


	#### Set the bathymetry field
  ## SD_O sets the absolute scale of variability in depth e.g. from 0-100, from 0-500, etc
  ## scale sets the coarseness of spatial variation: the bigger, the more things are correlated in space.
  ## a small value e.g. 1 will make the map very patchy (each cell is independent of its neighboor)
	set.seed(seed_input)
	model_bathym <- RMgauss(var=Sim_Settings$SD_O^2,
	                        scale=Sim_Settings$SpatialScale)
	map_grid <- expand.grid(X=Sim_Settings$Range_X,
	                        Y=Sim_Settings$Range_Y)
	Bathym <- RFsimulate(model_bathym, x=map_grid)
	data.bathym <- data.frame(ID = 1:nrow(map_grid),
	                          map_grid,
	                          depth=Bathym@data[,1])
	data.bathym$depth = data.bathym$depth + abs(min(data.bathym$depth))	# to avoid getting negative depth here depth takes positive real number
	# image.plot(Sim_Settings$Range_X, Sim_Settings$Range_Y, matrix(data.bathym$depth,nrow=length(Sim_Settings$Range_X), ncol=length(Sim_Settings$Range_Y)))

	#### Set the pop mvt param from the simulation settings for each season (here month)
	Par_mvt_adult <- lapply(1:12, function(x)
	  rbind(Sim_Settings$Fish_dist_par1[x,],
	        Sim_Settings$Fish_dist_par2,
	        Sim_Settings$Fish_depth_par1[x,],
	        Sim_Settings$Fish_depth_par2[x,]));

	#### Calculate the movement matrices
	if (Sim_Settings$parallel == FALSE) Mvt_mat_adult <- lapply(1:12, function(x)
	  lapply(1:Sim_Settings$n_species,
	         function(xxx) Mvt_matrix(Pop_param=Par_mvt_adult[[x]][,xxx],
	                                  Depth_eff="TRUE",
	                                  Dist_eff="TRUE",
	                                  Lat_eff="TRUE",
	                                  Dist_func=Sim_Settings$func_mvt_dist[xxx],
	                                  Depth_func=Sim_Settings$func_mvt_depth[xxx],
	                                  Lat_func=Sim_Settings$func_mvt_lat[xxx],
	                                  Eastings=Sim_Settings$Range_X,
	                                  Northings=Sim_Settings$Range_Y,
	                                  data.bathym)))
	if (Sim_Settings$parallel == TRUE) {
	  cl <- makeCluster(getOption("cl.cores", 4))
	  clusterExport(cl, varlist=list("Sim_Settings",
	                                 "Mvt_upd1",
	                                 "Mvt_matrix",
	                                 "Par_mvt_adult",
	                                 "data.bathym"))
	  Mvt_mat_adult <- parLapply(cl, 1:12, function(x)
	    lapply(1:Sim_Settings$n_species, function(xxx)
	      Mvt_matrix(Pop_param=Par_mvt_adult[[x]][,xxx],
	                 Depth_eff="TRUE",
	                 Dist_eff="TRUE",
	                 Lat_eff="TRUE",
	                 Dist_func=Sim_Settings$func_mvt_dist[xxx],
	                 Depth_func=Sim_Settings$func_mvt_depth[xxx],
	                 Lat_func=Sim_Settings$func_mvt_lat[xxx],
	                 Eastings=Sim_Settings$Range_X,
	                 Northings=Sim_Settings$Range_Y,
	                 data.bathym)))
	}

	#### Biomass dynamics: similarly to the work from Thorson et al but with more features
	### 1. Determining the initial population distribution
	Pop_adult <- sapply(1:Sim_Settings$n_species,
	                    function(x) Stable_pop_dist(Mvt_mat_adult[[1]][[x]],
	                                                Sim_Settings$B0[x],
	                                                Sim_Settings$Range_X,
	                                                Sim_Settings$Range_Y))

	if(Sim_Settings$plotting==TRUE){
		X11()
		nf <- layout(matrix(1:6, nrow=3))
		par(mar=c(1,1,1,1))
		fields::image.plot(Sim_Settings$Range_X,
		                   Sim_Settings$Range_Y,
		                   matrix(data.bathym$depth,
		                          nrow=length(Sim_Settings$Range_X),
		                          ncol=length(Sim_Settings$Range_Y)))
		for (sp in 1:Sim_Settings$n_species) fields::image.plot(Sim_Settings$Range_X,
		                                                        Sim_Settings$Range_Y,
		                                                        matrix(Pop_adult[,sp],
		                                                               length(Sim_Settings$Range_X),
		                                                               length(Sim_Settings$Range_Y)))
	}

	Biomass <- array(NA,
	                 dim=c(Sim_Settings$n_years,
	                           12,
	                           nrow(data.bathym),
	                           Sim_Settings$n_species))
	Biomass[1,1,,] <- Pop_adult
	Biomass[1,1,,] <- apply(Biomass[1,1,,], 2,
	                        function(x) replace(x, which(x<=0), 0))

	### 2. Structuring the vessel dynamics

	## generate total effort by year & month (total effort will be randomly sampled with log normal error around a logistic type function)
	Effort <- array(0, dim=c(Sim_Settings$n_years, 12));
	Mean_Effort <- array(0, dim=c(Sim_Settings$n_years, 12));
	map.size <- length(Sim_Settings$Range_X)*length(Sim_Settings$Range_Y)
	Effort_area_year <- array(0, dim=c(Sim_Settings$n_years, 12, map.size));

	Sig_effort <- sqrt(log(Sim_Settings$CV_effort^2+1))
	Sig_vessel <- sqrt(log(Sim_Settings$CV_vessel^2+1))
	qq_vessel <- sapply(1:Sim_Settings$n_species, function(x) rlnorm(Sim_Settings$Nvessels, log(Sim_Settings$qq_original[x])-Sig_vessel^2/2, Sig_vessel))

	# use of tweedie distribution to generate catch data for individual boat
	CPUE_tot <- array(NA, dim=c(Sim_Settings$n_years, 12, nrow(data.bathym)))
	Catch_area_year <- array(0, dim=c(Sim_Settings$n_years, 12, map.size, Sim_Settings$n_species));
	Catch_area_year_ind <- c();

	# Define historic fishing regions for each vessel randomly
	which_regions <- t(sapply(rep(sum(Sim_Settings$Nregion),Sim_Settings$Nvessels), function(x) sample(1:sum(Sim_Settings$Nregion), x, replace=TRUE)))
	areas <- equal_partition( expand.grid(X = Sim_Settings$Range_X, Y = Sim_Settings$Range_Y), Sim_Settings$Nregion[1], Sim_Settings$Nregion[2], Sim_Settings$Range_X, Sim_Settings$Range_Y)$area

	# Keep track of the population abundance/number that left the fishing ground
	Gone_outside <- array(0, dim=c(Sim_Settings$n_years, 12, 1, Sim_Settings$n_species))
  Gone_total <- rep(0, Sim_Settings$n_species)  ## a dummy variable to keep track of the total population that left

	#### Updating the population and generate catch data according to the above specifications
	for (iyear in 1:Sim_Settings$n_years){
	  for (month in 1:12){
	    ### If the population migrates out of the fishing area, do that before the fishing
	    for (sp in 1:Sim_Settings$n_species){
	      if (Sim_Settings$Rangeshift_proportion[month, sp]==0) Gone_total[sp] = 0  ## Refresh the counter
	      if (Sim_Settings$Rangeshift_proportion[month, sp]>0){
  	      if (month == 1) {
  	        rate1 = Sim_Settings$Rangeshift_proportion[12, sp]
  	        rate <- Sim_Settings$Rangeshift_proportion[1, sp] - rate1
  	      }
  	      if (month > 1) {
  	        rate1 = Sim_Settings$Rangeshift_proportion[month-1, sp]
  	        rate <- Sim_Settings$Rangeshift_proportion[month, sp] - rate1
  	      }
  	      if (rate>0){
  	        Biomass[iyear,month,,sp] <- Biomass[iyear,month,,sp]/(1-rate1)*Sim_Settings$Rangeshift_proportion[month, sp]
  	        Gone_outside[iyear,month,1,sp] <- sum(Biomass[iyear,month,,sp]*(1-(1-Sim_Settings$Rangeshift_proportion[month, sp])/(1-rate1)))
  	        Gone_total[sp] = Gone_total[sp] + Gone_outside[iyear,month,1,sp]
  	      }
	      }
	    }

	    set.seed(seed_input + iyear*12 + month)
  		### do vessel change their fishing preference over the year (this ONLY controls vessel concentration factor)
	    Preference=1
	    if(Sim_Settings$Changing_preference==TRUE) Preference <- 2-exp(-0.1*iyear)

  		### Assigning total effort in a year
  		Mean_Effort[iyear,] <- (Sim_Settings$Tot_effort/(1+exp(-0.1*iyear)))*Sim_Settings$Effort_alloc_month/sum(Sim_Settings$Effort_alloc_month)		# mean effort by year
  		Effort[iyear,] <- trunc(rlnorm(12, log(Mean_Effort[iyear,]-Sig_effort^2/2), Sig_effort))		# effort by year

  		### just an old placeholder (not very efficient)
  		qq <- Sim_Settings$qq_original

  		### Continuous catch equation - calculating the expected revenue
  		CPUE_tot[iyear,month,] <- apply(Biomass[iyear,month,,]*matrix((1-exp(-qq)), nrow=map.size, ncol=Sim_Settings$n_species, byrow=T) * matrix(Sim_Settings$price_fish[iyear,], nrow=map.size, ncol=Sim_Settings$n_species, byrow=T),1,sum)

  		### If a site is not worth going (expected revenue is negative)
  		CPUE_tot[iyear,month,][which(CPUE_tot[iyear,month,] < 0 )]<- 0

  		### Distribute the total effort according to the above expected revenue
  		p <- CPUE_tot[iyear,month,]^Preference/sum(CPUE_tot[iyear,month,]^Preference);min(p);max(p)
  		Effort_area_year[iyear,month,] <- rmultinom(1, size=Effort[iyear,], p=p)

  		### Then calculate the total catch in each area
  		aa <- c(); AA <- c()
  		Catch_year_area_mat <- matrix(0, nrow=map.size, ncol=Sim_Settings$n_species)

  		vessel_seed <- sample(1:Sim_Settings$vessel_seeds, 1)
  		set.seed(vessel_seed)     # this piece of code is to create heterogeneity in the vessel fishing times (without it all vessels fish about the same number of times)
  		for (xyz in which(Effort_area_year[iyear,month,]>0)){
  			vessel_pool_area <- (1:Sim_Settings$Nvessels)[apply(which_regions, 1, function(x) areas[xyz] %in% x)]
  		  which.vessel.fished <- sample(vessel_pool_area, Effort_area_year[iyear,month,xyz], replace=TRUE)

  			# This is the code using the generating random obs error per vessel & species
  			if(Sim_Settings$do.tweedie==TRUE) rand.vessel <- matrix(sapply(1:Sim_Settings$n_species, function(x) rtweedie( Effort_area_year[iyear,month,xyz], mu= qq_vessel[which.vessel.fished,x], power=Sim_Settings$xi[x], phi=Sim_Settings$phi[x])),ncol=Sim_Settings$n_species)
  		  # if(Sim_Settings$do.tweedie==TRUE) rand.vessel <- matrix(sapply(1:Sim_Settings$n_species, function(x) rtweedie_new(n=Effort_area_year[iyear,month,xyz], mu= qq_vessel[which.vessel.fished,x], power=Sim_Settings$xi[x], phi=Sim_Settings$phi[x])),ncol=Sim_Settings$n_species)
  		  if(Sim_Settings$do.tweedie==FALSE) rand.vessel <- matrix(sapply(1:Sim_Settings$n_species, function(x) qq_vessel[which.vessel.fished,x]),ncol=Sim_Settings$n_species)
  			catch_area_vessel <- sapply(1:Sim_Settings$n_species, function(Y) { hum <- Biomass[iyear,month,xyz,Y]*(1-exp(-sum(rand.vessel[,Y]))); ifelse(hum==0, catch_area_vessel <- rep(0, Effort_area_year[iyear,month,xyz]), catch_area_vessel <- hum*rand.vessel[,Y]/sum(rand.vessel[,Y])); return(catch_area_vessel)})
  			# now truncate value when necessary
  			if (any(Sim_Settings$catch_trunc == 1)) {
  			  to_trunc <- which(Sim_Settings$catch_trunc == 1)
  			  if (length(catch_area_vessel) == Sim_Settings$n_species)  catch_area_vessel[to_trunc ] <- trunc(catch_area_vessel[to_trunc ])
  			  if (length(catch_area_vessel) > Sim_Settings$n_species)  catch_area_vessel[,to_trunc ] <- trunc(catch_area_vessel[,to_trunc ])
  			}
  			catch_area_vessel <- data.frame(iyear, month, areas[xyz], matrix(rep(c(data.bathym[xyz,-1]), each= Effort_area_year[iyear,month,xyz]),nrow= Effort_area_year[iyear,month,xyz]), which.vessel.fished, matrix(catch_area_vessel,ncol=Sim_Settings$n_species));
  			catch_area_vessel <- matrix(sapply( catch_area_vessel, FUN=as.numeric ), nrow=nrow(catch_area_vessel))
  			colnames(catch_area_vessel) <- c("year", "month", "fishing_district", "X", "Y", "depth", "vessel", paste0("Sp", 1:Sim_Settings$n_species))
  			Catch_year_area_mat[xyz,] <- colSums(catch_area_vessel[,grep("Sp", colnames(catch_area_vessel)),drop=FALSE])

  			AA <- rbind(AA, catch_area_vessel)
  		}

  		Catch_area_year_ind <- rbind(Catch_area_year_ind, AA)
  		Catch_area_year[iyear,month,,] <- Catch_year_area_mat

     	### Then update the population = growth & catch, then at a specific month, we have the process error (e.g. rec dev)
  		if (month < 12){
    		temp <- (Biomass[iyear,month,,]+Sim_Settings$r*Biomass[iyear,month,,]*(1-Biomass[iyear,month,,]/Biomass[1,1,,])-Catch_area_year[iyear,month,,])
    		temp <- apply(temp,2,function(x) replace(x, which(is.na(x)==TRUE | x<=0),0))
    		temp <- sapply(1:Sim_Settings$n_species, function(x) {if (month %in% Sim_Settings$sigma_p_timing[x]) out <- sapply(seq_along(temp[,x]), function(y) rlnorm(1, log(temp[y,x])- Sim_Settings$sigma_p[x]^2/2, Sim_Settings$sigma_p[x])) else temp[,x]})
    		Biomass[iyear,month+1,,] <- apply(temp,2,function(x) replace(x, which(is.na(x)==TRUE | x<=0),0))
  		}
  		if (month == 12 & iyear < Sim_Settings$n_years){
    		temp <- Biomass[iyear,month,,]+Sim_Settings$r*Biomass[iyear,month,,]*(1-Biomass[iyear,month,,]/Biomass[1,1,,])-Catch_area_year[iyear,month,,]
    		temp <- apply(temp,2,function(x) replace(x, which(is.na(x)==TRUE | x<=0),0))
    		temp <- sapply(1:Sim_Settings$n_species, function(x) {if (month %in% Sim_Settings$sigma_p_timing[x]) out <- sapply(seq_along(temp[,x]), function(y) rlnorm(1, log(temp[y,x])- Sim_Settings$sigma_p[x]^2/2, Sim_Settings$sigma_p[x])) else temp[,x]})
    		Biomass[iyear+1,1,,] <- apply(temp,2,function(x) replace(x, which(is.na(x)==TRUE | x<=0),0))
  		}

  		### population mvt at the end of each month (to their favorite habitat)
  		if (month < 12){
  		  if (Sim_Settings$fish.mvt==TRUE)	Biomass[iyear,month+1,,] <- sapply(1:Sim_Settings$n_species, function(x) t(Mvt_mat_adult[[month]][[x]])%*%Biomass[iyear,month+1,,x])
  		  if (Sim_Settings$fish.mvt==FALSE)	Biomass[iyear,month+1,,] <- Biomass[iyear,month+1,,]
  		  Biomass[iyear,month+1,,] <- apply(Biomass[iyear,month+1,,],2,function(x) replace(x, which(is.na(x)==TRUE | x<=0),0))
  		}
  		if (month == 12 & iyear < Sim_Settings$n_years){
  		  if (Sim_Settings$fish.mvt==TRUE)	Biomass[iyear+1,1,,] <- sapply(1:Sim_Settings$n_species, function(x) t(Mvt_mat_adult[[month]][[x]])%*%Biomass[iyear+1,1,,x])
  		  if (Sim_Settings$fish.mvt==FALSE)	Biomass[iyear+1,1,,] <- Biomass[iyear+1,1,,]
  		  Biomass[iyear+1,1,,] <- apply(Biomass[iyear+1,1,,],2,function(x) replace(x, which(is.na(x)==TRUE | x<=0),0))
  		}


  		### The population that left comes back to the fishing ground and redistribute to the other grid cells
  		coming_back <- 0
  		for (sp in 1:Sim_Settings$n_species){
    		  if (month < 12) {
    		    rate2 = Sim_Settings$Rangeshift_proportion[month+1, sp]
    		    rate_back = rate2 - Sim_Settings$Rangeshift_proportion[month, sp]
    		  }
    		  if (month == 12) {
    		    rate2 = Sim_Settings$Rangeshift_proportion[1, sp]
    		    rate_back = rate2 - Sim_Settings$Rangeshift_proportion[month, sp]
    		  }
    		  if (rate_back < 0){
    		    coming_back <- Gone_total/Sim_Settings$Rangeshift_proportion[month, sp] * (1- rate2)
      		  ## Now we need to redistribute these animals that will be going back to the rest of the zone
      		  if (month < 12) {
      		    temp = Par_mvt_adult[[month+1]]
      		    temp[1,sp] = Sim_Settings$Rangeshift_distance[sp]
      		    Mvt_migration <- Mvt_upd1(loc = length(Sim_Settings$Range_X)*length(Sim_Settings$Range_Y)-(Sim_Settings$Range_X-1), Pop_param=temp[,sp], Depth_eff="TRUE", Dist_eff="TRUE", Lat_eff="TRUE", Dist_func=Sim_Settings$func_mvt_dist[sp], Depth_func=Sim_Settings$func_mvt_depth[sp], Lat_func=Sim_Settings$func_mvt_lat[sp], data.bathym)

      		    Biomass[iyear,month+1,,sp] <- Biomass[iyear,month+1,,sp] + Mvt_migration[[month]]*coming_back
      		    Biomass[iyear,month+1,,sp] <- replace(Biomass[iyear,month+1,,sp], which(is.na(Biomass[iyear,month+1,,sp])==TRUE | Biomass[iyear,month+1,,sp]<=0),0)
      		  }
      		  if (month == 12 & iyear < Sim_Settings$n_years){
      		    temp = Par_mvt_adult[[1]]
      		    temp[1,sp] = Sim_Settings$Rangeshift_distance[sp]
      		    Mvt_migration <- Mvt_upd1(loc = length(Sim_Settings$Range_X)*length(Sim_Settings$Range_Y)-(Sim_Settings$Range_X-1), Pop_param=temp[,sp], Depth_eff="TRUE", Dist_eff="TRUE", Lat_eff="TRUE", Dist_func=Sim_Settings$func_mvt_dist[sp], Depth_func=Sim_Settings$func_mvt_depth[sp], Lat_func=Sim_Settings$func_mvt_lat[sp], data.bathym)

      		    Biomass[iyear+1,1,,sp] <- Biomass[iyear+1,1,,sp] + Mvt_migration[[month]]*coming_back
      		    Biomass[iyear+1,1,,sp] <- replace(Biomass[iyear+1,1,,sp], which(is.na(Biomass[iyear+1,1,,sp])==TRUE | Biomass[iyear+1,1,,sp]<=0),0)
      		  }
    		  }
    		}


  		if (Sim_Settings$Interactive == TRUE) print(iyear)
	  }
	 }

	#### Return data

	Return = list(Data= Catch_area_year_ind, Biomass=Biomass, bathym=data.bathym)
	return(Return)
}
