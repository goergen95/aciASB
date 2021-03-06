library(stringr)
library(raster)
library(ggplot2)
library(reshape2)
library(dplyr)
library(purrr)
library(gridExtra)
library(ggpubr)

# select relevant parameters
paras = str_to_upper(c("rh"))

# read parameters observation number files into raster stack in a list
paraStacks = lapply(paras, function(x){
  stack(list.files(paste0("../results/",x), pattern = ".tif", full.names = TRUE))
})


# vector indicating the years for which to calculate mean values
years = 2003:2018

if (!file.exists("../results/values/yearly_Precipitation.rds")){
  # nested lapply loop through every parameter and the years to get one mean value per parameter and year 
  yearlySums = lapply(paraStacks, function(x){

    tmpLS = lapply(years, function(y){
      tmp = x[[grep(as.character(y), names(x))]]
      beginCluster(parallel::detectCores()-1)
      ysum = clusterR(tmp, calc, args=list(fun=sum, na.rm=TRUE))
      endCluster()
      tmp2 = c(na.omit(values(ysum)))
      df = data.frame(year=rep(y, length(tmp2)), values = tmp2)
      return(df)
    })
    xmean = do.call(rbind, tmpLS)
    return(xmean)
  })
  
  # preparation for plotting
  names(yearlySums) = paras
  for (i in 1:length(paras)){
    yearlySums[[paras[i]]]$type = paras[i]
  }
  
  df = as_tibble(do.call(rbind, yearlySums))
  #df$year = years
  #df = melt(df, id.vars = "year")
  saveRDS(df, file = "../results/values/yearly_Precipitation_RH.rds")
} else {
  df = readRDS("../results/values/yearly_Precipitation.rds")
}


meanVals = df %>% 
  group_by(year) %>%
  summarize(mean = mean(values))

# using ggplot2 to plot every parameter in a facet
meanplot = ggplot(df, aes(x=as.factor(year)))+
  geom_boxplot(aes(y=values, group=as.factor(year)))+
  geom_point(data=meanVals, aes(x=as.factor(year), y=mean), color="red")+
  scale_x_discrete(limits=as.factor(years))+
  xlab("Year")+
  ylab("Relative Humidity [%]")+
  #geom_text(data=regCoef,
  #          mapping= aes(x=2017, y=10, label= paste("slope: ", round(slope, 2), sep="")))+
  #geom_text(data=regCoef,
  #          mapping= aes(x=2014, y=10, label= paste("R²: ", round(r, 4), sep="")))+
  theme_minimal()+
  theme(axis.text.x = element_text(angle = 45),
        text = element_text(size = 20))

# saving plot to disk
ggsave(plot=meanplot, file = "../results/plots/P_yearly.png", dpi=300, device="png", width = 20, height = 10)

