# Calculate the partitioning of coexistence mechanisms using weighted averages
# and compare invader to resident growth rates
# Calculations are based on Ellner et al. 2018 Ecology Letters

# load the data
#load("model.dat.output.RData")
source("models_no_facilitation.R")

# First determine how common each environmental type is
# what about for what we actually see in terms of the number of years in each env. condition
# first read in the data
rain <- read_csv("Data/PRISM_brownsvalley_long.csv", skip = 10) %>%
  mutate(ppt = `ppt (inches)`*2.54*10) %>%
  separate(Date, c("year", "month")) %>%
  mutate(year = as.numeric(year),
         month = as.numeric(month)) %>%
  mutate(year = ifelse(month == 12 | month == 11 | month == 10 | month == 9, year + 1, year)) %>%
  mutate(season = "Early",
         season = ifelse(month == 2 | month == 3 | month == 4, "Late", season)) %>%
  filter(month != 5, month != 6, month!= 7, month != 8)

## Summarize by year 
## Using 50% as the cutoff 
rainsummary <-  rain %>%
  group_by(year, season) %>%
  summarize(ppt = sum(ppt)) %>%
  spread(season, ppt) %>%
  mutate(Total = Early + Late) 

rainsummary <- rainsummary %>%
  mutate(raintype = "controlRain",
         raintype = ifelse(Early < quantile(rainsummary$Early, .5), "fallDry", raintype),
         raintype = ifelse(Late < quantile(rainsummary$Late, .5), "springDry", raintype),
         raintype = ifelse(Total < quantile(rainsummary$Total, .5), "consistentDry", raintype)) 

fall.dry <- length(which(rainsummary$raintype == "fallDry")) / nrow(rainsummary)
spring.dry <- length(which(rainsummary$raintype == "springDry")) / nrow(rainsummary)
consistent.dry <- length(which(rainsummary$raintype == "consistentDry")) / nrow(rainsummary)
control.rain <- length(which(rainsummary$raintype == "controlRain")) / nrow(rainsummary)

# ------------------------------------------------------------------------------------
# Functions for use in coexistence calcualtions

# Determine equilibrium conditions for each species in isolation 
pop.equilibrium <- function (N0, s, g, a_intra, lambda) {
  # to run for only a single timestep
  N <- s*(1-g)*N0 + N0*(lambda*g)/(1+a_intra*N0)
  return(N)
}

# invader population growth rate one time step forward
pop.invade <- function (N0, resident, s, g, a_inter, lambda) {
  # to run for only a single timestep
  N <- s*(1-g)*N0 + N0*(lambda*g)/(1+a_inter*resident)
  return(N)
}

# resident population growth rate one time step forward
pop.resident <- function (N0, resident, s, g, a_intra, a_inter, lambda) {
  # to run for only a single timestep
  N <- s*(1-g)*resident + resident*(lambda*g)/(1+a_intra*resident+a_inter*N0)
  return(N)
}

# ------------------------------------------------------------------------------------
# run models
# first determine resident equilibrium abundances and low density growth rates
# without partitioning coexistence

avena <- subset(model.dat, species=="Avena")
erodium <- subset(model.dat, species=="Erodium")

## Set germination and survival fractions from the literature
as <- .4
ag <- .9
es <- .82
eg <- .6

# use the timeseries of environmental conditions for environmental variability
# for avena
N0 <- 550
time <- length(rainsummary$raintype)
N_avena <- rep(NA, time)
N_avena[1] <- N0

for (t in 1:time) {
  params <- subset(avena, treatment==rainsummary$raintype[t])
  N_avena[t+1] <- pop.equilibrium(N0=N_avena[t], s=as, g=ag, a_intra=params$aiA, lambda=params$lambda)
}

# check output
plot(seq(1:(time+1)), N_avena, type="l")


# for erodium
N0 <- 70
time <- length(rainsummary$raintype)
N_erodium <- rep(NA, time)
N_erodium[1] <- N0

for (t in 1:time) {
  params <- subset(erodium, treatment==rainsummary$raintype[t])
  N_erodium[t+1] <- pop.equilibrium(N0=N_erodium[t], s=es, g=eg, a_intra=params$aiE, lambda=params$lambda)
}

# check output
plot(seq(1:(time+1)), N_erodium, type="l")

# invade avena first
avena_invade <- rep (NA, 72)
erodium_resident <- rep (NA, 72)
temp <- 1
for (t in 50:time) {
  params <- subset(avena, treatment==rainsummary$raintype[t])
  params_resident <- subset(erodium, treatment==rainsummary$raintype[t])
  avena_invade[temp] <- pop.invade(N0=1, resident=N_erodium[t], s=as, g=ag, a_inter=params$aiE, lambda=params$lambda)
  
  # sanity check that the resident isn't affected
  erodium_new <- pop.resident(N0=1, resident=N_erodium[t], s=es, g=eg, 
                              a_intra=params_resident$aiE, a_inter=params_resident$aiA, 
                              lambda=params_resident$lambda)
  erodium_resident[temp] <- erodium_new/N_erodium[t]
  
  temp  <- temp + 1 
}

# then have erodium invade into avena
erodium_invade <- rep (NA, 72)
avena_resident <- rep (NA, 72)
temp <- 1
for (t in 50:time) {
  params <- subset(erodium, treatment==rainsummary$raintype[t])
  params_resident <- subset(avena, treatment==rainsummary$raintype[t])
  
  erodium_invade[temp] <- pop.invade(N0=1, resident=N_avena[t], s=es, g=eg, a_inter=params$aiA, lambda=params$lambda)
  
  # sanity check that the resident isn't affected
  avena_new <- pop.resident(N0=1, resident=N_avena[t], s=as, g=ag, 
                            a_intra=params_resident$aiA, a_inter=params_resident$aiE, 
                            lambda=params_resident$lambda)
  avena_resident[temp] <- avena_new/N_avena[t]
  temp  <- temp + 1 
}

avena_invader <- log(avena_invade)
erodium_invader <- log(erodium_invade)

avena_r <- log(avena_resident)
erodium_r <- log(erodium_resident)

# ------------------------------------------------------------------------------------
# growth rate partitioning of each species as the invader
# The environment affects both the growth rates AND the competition experienced (e.g. Rachel & Margie's paper),
# so, we won't partition the storage effect in the classic Chesson way
# Rather, we will follow Ellner et al. 2018 to look at how environmental effects on 
# intransic growth rates, competition, and their combined effects alter coexistence
# for each species

# first calculate the invasion rate under average conditions (weighted), with NO variation in 
# intrinsic growth rates or alphas

# use the timeseries of environmental conditions for environmental variability
# determine weighted average intraspecific alpha, interspecific alpha, and lambda values
# for each species

a_intra_weighted <- consistent.dry*avena$aiA[1]+fall.dry*avena$aiA[2]+
  spring.dry*avena$aiA[3]+control.rain*avena$aiA[4]
a_inter_weighted <- consistent.dry*avena$aiE[1]+fall.dry*avena$aiE[2]+
  spring.dry*avena$aiE[3]+control.rain*avena$aiE[4]
a_lambda_weighted <- consistent.dry*avena$lambda[1]+fall.dry*avena$lambda[2]+
  spring.dry*avena$lambda[3]+control.rain*avena$lambda[4]

e_intra_weighted <- consistent.dry*erodium$aiE[1]+fall.dry*erodium$aiE[2]+
  spring.dry*erodium$aiE[3]+control.rain*erodium$aiE[4]
e_inter_weighted <- consistent.dry*erodium$aiA[1]+fall.dry*erodium$aiA[2]+
  spring.dry*erodium$aiA[3]+control.rain*erodium$aiA[4]
e_lambda_weighted <- consistent.dry*erodium$lambda[1]+fall.dry*erodium$lambda[2]+
  spring.dry*erodium$lambda[3]+control.rain*erodium$lambda[4]


# ----------------------------------------------------------------------------------------
# First invade each species into the other at equilibrium with no variation
# find resident equilibriums

N0 <- 550
avena_no_var <- rep(NA, time)
avena_no_var[1] <- N0
for (t in 1:time) {
  avena_no_var[t+1] <- pop.equilibrium(N0=avena_no_var[t], s=as, g=ag, 
                                       a_intra=a_intra_weighted, lambda=a_lambda_weighted)
}

# check output
plot(seq(1:(time+1)), avena_no_var, type="l")


# for erodium
N0 <- 70
erodium_no_var <- rep(NA, time)
erodium_no_var[1] <- N0

for (t in 1:time) {
  erodium_no_var[t+1] <- pop.equilibrium(N0=erodium_no_var[t], s=es, g=eg, a_intra=e_intra_weighted, 
                                         lambda=e_lambda_weighted)
}

# check output
plot(seq(1:(time+1)), erodium_no_var, type="l")

# now invade each species into the resident
avena_invade_no_var <- pop.invade(N0=1, resident=erodium_no_var[time], s=as, g=ag, 
                                  a_inter=a_inter_weighted, lambda=a_lambda_weighted)

erodium_invade_no_var <- pop.invade(N0=1, resident=avena_no_var[time], s=es, g=eg, 
                                    a_inter=e_inter_weighted, lambda=e_lambda_weighted)

# determine any changes in the residents' abundances
avena_resident_no_var_next <- pop.resident(N0=1, resident=avena_no_var[time], s=as, g=ag, 
                                      a_intra = a_intra_weighted,
                                      a_inter=a_inter_weighted, lambda=a_lambda_weighted)

avena_resident_no_var <- avena_no_var[time]/avena_resident_no_var_next

# erodium
erodium_resident_no_var_next <- pop.resident(N0=1, resident=erodium_no_var[time], s=es, g=eg, 
                                           a_intra = e_intra_weighted,
                                           a_inter=e_inter_weighted, lambda=e_lambda_weighted)

erodium_resident_no_var <- erodium_no_var[time]/erodium_resident_no_var_next

avena_epsilon_0 <- log(avena_invade_no_var)
erodium_epsilon_0 <- log(erodium_invade_no_var)
resident_avena_epsilon_0 <- log(avena_resident_no_var)
resident_erodium_epsilon_0 <- log(erodium_resident_no_var)

# ----------------------------------------------------------------------------------------
# second calculate the invasion rate with variable intrinsic growth rates (lambda), 
# but with NO variation in alphas

# find resident equilibrium with variable growth rates
# for avena
N0 <- 550
R_avena_var_lambda <- rep(NA, time)
R_avena_var_lambda[1] <- N0

for (t in 1:time) {
  params <- subset(avena, treatment==rainsummary$raintype[t])
  R_avena_var_lambda[t+1] <- pop.equilibrium(N0=R_avena_var_lambda[t], s=as, g=ag, 
                                             a_intra=a_intra_weighted, lambda=params$lambda)
}

# check output
plot(seq(1:(time+1)), R_avena_var_lambda, type="l")

# for erodium
N0 <- 70
R_erodium_var_lambda <- rep(NA, time)
R_erodium_var_lambda[1] <- N0

for (t in 1:time) {
  params <- subset(erodium, treatment==rainsummary$raintype[t])
  R_erodium_var_lambda[t+1] <- pop.equilibrium(N0=R_erodium_var_lambda[t], s=es, g=eg, 
                                               a_intra=e_intra_weighted, lambda=params$lambda)
}

# check output
plot(seq(1:(time+1)), R_erodium_var_lambda, type="l")

# Then invade each species into the other at equilibrium with variation in lambda only
# invade avena first
I_avena_var_lambda <- rep (NA, 72)
erodium_resident_var_lambda <- rep (NA, 72)
temp <- 1

for (t in 50:time) {
  params_avena <- subset(avena, treatment==rainsummary$raintype[t])
  params_erodium <- subset(erodium, treatment==rainsummary$raintype[t])
  
  #invader
  I_avena_var_lambda[temp] <- pop.invade(N0=1, resident=R_erodium_var_lambda[t], s=as, g=ag, 
                                         a_inter=a_inter_weighted, lambda=params_avena$lambda)
  
  #resident
  erodium_res_var_lambda <- pop.resident(N0=1, resident=R_erodium_var_lambda[t], s=es, g=eg, 
                                         a_intra = e_intra_weighted, a_inter=e_inter_weighted, 
                                         lambda=params_erodium$lambda)
  
  erodium_resident_var_lambda[temp] <- erodium_res_var_lambda /  R_erodium_var_lambda[t]
  
  temp  <- temp + 1 
}

# then have erodium invade into avena
I_erodium_var_lambda <- rep (NA, 72)
avena_resident_var_lambda <- rep (NA, 72)
temp <- 1

for (t in 50:time) {
  params_avena <- subset(avena, treatment==rainsummary$raintype[t])
  params_erodium <- subset(erodium, treatment==rainsummary$raintype[t])
  
  # invader
  I_erodium_var_lambda[temp] <- pop.invade(N0=1, resident=R_avena_var_lambda[t], s=es, g=eg, 
                                           a_inter=e_inter_weighted, lambda=params_erodium$lambda)
  
  #resident
  avena_res_var_lambda <- pop.resident(N0=1, resident=R_avena_var_lambda[t], s=as, g=ag, 
                                         a_intra = a_intra_weighted, a_inter=a_inter_weighted, 
                                         lambda=params_avena$lambda)
  
  avena_resident_var_lambda[temp] <- avena_res_var_lambda /  R_avena_var_lambda[t]
  
  temp  <- temp + 1 
}

avena_epsilon_lambda <- log(mean(I_avena_var_lambda)) - avena_epsilon_0
erodium_epsilon_lambda <- log(mean(I_erodium_var_lambda)) - erodium_epsilon_0

resident_avena_epsilon_lambda <- log(mean(avena_resident_var_lambda)) - resident_avena_epsilon_0
resident_erodium_epsilon_lambda <- log(mean(erodium_resident_var_lambda)) - resident_erodium_epsilon_0

# ----------------------------------------------------------------------------------------
# third calculate the invasion rate with variable alphas, 
# but with NO variation in intrinsic growth rates

# find resident equilibrium with variable alphas
# for avena
N0 <- 550
R_avena_var_alpha <- rep(NA, time)
R_avena_var_alpha[1] <- N0

for (t in 1:time) {
  params <- subset(avena, treatment==rainsummary$raintype[t])
  R_avena_var_alpha[t+1] <- pop.equilibrium(N0=R_avena_var_alpha[t], s=as, g=ag, 
                                            a_intra=params$aiA, lambda=a_lambda_weighted)
}

# check output
plot(seq(1:(time+1)), R_avena_var_alpha, type="l")

# for erodium
N0 <- 70
R_erodium_var_alpha <- rep(NA, time)
R_erodium_var_alpha[1] <- N0

for (t in 1:time) {
  params <- subset(erodium, treatment==rainsummary$raintype[t])
  R_erodium_var_alpha[t+1] <- pop.equilibrium(N0=R_erodium_var_alpha[t], s=es, g=eg, 
                                              a_intra=params$aiE, lambda=e_lambda_weighted)
}

# check output
plot(seq(1:(time+1)), R_erodium_var_alpha, type="l")

# Then invade each species into the other at equilibrium with variation in alpha only
# invade avena first
I_avena_var_alpha <- rep (NA, 72)
erodium_resident_var_alpha <- rep (NA, 72)
temp <- 1

for (t in 50:time) {
  params_avena <- subset(avena, treatment==rainsummary$raintype[t])
  params_erodium <- subset(erodium, treatment==rainsummary$raintype[t])
  
  #invader
  I_avena_var_alpha[temp] <- pop.invade(N0=1, resident=R_erodium_var_alpha[t], s=as, g=ag, 
                                         a_inter=params_avena$aiE, lambda=a_lambda_weighted)
  
  #resident
  erodium_res_var_alpha <- pop.resident(N0=1, resident=R_erodium_var_alpha[t], s=es, g=eg, 
                                         a_intra = params_erodium$aiE, a_inter=params_erodium$aiA, 
                                         lambda=e_lambda_weighted)
  
  erodium_resident_var_alpha[temp] <- erodium_res_var_alpha /  R_erodium_var_alpha[t]
  
  temp  <- temp + 1 
}

# then have erodium invade into avena
I_erodium_var_alpha <- rep (NA, 72)
avena_resident_var_alpha <- rep (NA, 72)
temp <- 1

for (t in 50:time) {
  params_avena <- subset(avena, treatment==rainsummary$raintype[t])
  params_erodium <- subset(erodium, treatment==rainsummary$raintype[t])
  
  # invader
  I_erodium_var_alpha[temp] <- pop.invade(N0=1, resident=R_avena_var_alpha[t], s=es, g=eg, 
                                           a_inter=params_erodium$aiA, lambda=e_lambda_weighted)
  
  #resident
  avena_res_var_alpha <- pop.resident(N0=1, resident=R_avena_var_alpha[t], s=as, g=ag, 
                                       a_intra = params_avena$aiA, a_inter=params_avena$aiE, 
                                       lambda=a_lambda_weighted)
  
  avena_resident_var_alpha[temp] <- avena_res_var_alpha /  R_avena_var_alpha[t]
  
  temp  <- temp + 1 
}


avena_epsilon_alpha <- log(mean(I_avena_var_alpha)) - avena_epsilon_0
erodium_epsilon_alpha <- log(mean(I_erodium_var_alpha)) - erodium_epsilon_0

resident_avena_epsilon_alpha <- log(mean(avena_resident_var_alpha)) - resident_avena_epsilon_0
resident_erodium_epsilon_alpha <- log(mean(erodium_resident_var_alpha)) - resident_erodium_epsilon_0

# ----------------------------------------------------------------------------------------
# finally calculate the invasion rate with the interaction terms 

#invaders
avena_epsilon_interaction <- mean(avena_invader) - 
  (avena_epsilon_0 + avena_epsilon_alpha + avena_epsilon_lambda)
erodium_epsilon_interaction <- mean(erodium_invader) - 
  (erodium_epsilon_0 + erodium_epsilon_alpha + erodium_epsilon_lambda)

# residents
resident_avena_epsilon_interaction <- mean(avena_r) - 
  (resident_avena_epsilon_0 + resident_avena_epsilon_alpha + resident_avena_epsilon_lambda)
resident_erodium_epsilon_interaction <- mean(erodium_r) - 
  (resident_erodium_epsilon_0 + resident_erodium_epsilon_alpha + resident_erodium_epsilon_lambda)

# ----------------------------------------------------------------------------------------
# double check it all works
avena_LDGR <- mean(avena_invader) - mean(erodium_r)
erodium_LDGR <- mean(erodium_invader) - mean(avena_r)

# invader only -- without invader-resident comparison
avena_results_weighted <- c(mean(avena_invader), avena_epsilon_0, avena_epsilon_alpha, 
                   avena_epsilon_lambda, avena_epsilon_interaction)
erodium_results_weighted <- c(mean(erodium_invader), erodium_epsilon_0, erodium_epsilon_alpha, 
                     erodium_epsilon_lambda, erodium_epsilon_interaction)

# with invader resident comparison
ir_avena_results_weighted <- c(avena_LDGR, (avena_epsilon_0-resident_erodium_epsilon_0), 
                               (avena_epsilon_alpha-resident_erodium_epsilon_alpha), 
                               (avena_epsilon_lambda-resident_erodium_epsilon_lambda), 
                               (avena_epsilon_interaction-resident_erodium_epsilon_interaction))

ir_erodium_results_weighted <- c(erodium_LDGR, (erodium_epsilon_0-resident_avena_epsilon_0), 
                                 (erodium_epsilon_alpha-resident_avena_epsilon_alpha), 
                                 (erodium_epsilon_lambda-resident_avena_epsilon_lambda), 
                                  (erodium_epsilon_interaction-resident_avena_epsilon_interaction))

# check that all epsilons add to give the LDGR
# first for invader only
#avena_epsilon_0 + avena_epsilon_alpha + avena_epsilon_lambda + avena_epsilon_interaction

#erodium_epsilon_0 + erodium_epsilon_alpha + erodium_epsilon_lambda + erodium_epsilon_interaction

# then for invader-resident comparisons
#(avena_epsilon_0-resident_erodium_epsilon_0) + (avena_epsilon_alpha-resident_erodium_epsilon_alpha) + 
#  (avena_epsilon_lambda-resident_erodium_epsilon_lambda) + (avena_epsilon_interaction- resident_erodium_epsilon_interaction)

#(erodium_epsilon_0-resident_avena_epsilon_0) + (erodium_epsilon_alpha-resident_avena_epsilon_alpha) + 
#  (erodium_epsilon_lambda-resident_avena_epsilon_lambda) + (erodium_epsilon_interaction-resident_avena_epsilon_interaction)
