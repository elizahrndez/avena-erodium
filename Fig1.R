source("seeds_datasummary.R")

library(tidyverse)
library(here)
library(grid)

## RAW VISUAL
togdat2 <- togdat %>%
  mutate(treatment = as.character(treatment)) %>%
  #   mutate(treatment = revalue(treatment, c(fallDry = "Fall dry", consistentDry = "Consistent dry", springDry = "Spring dry", controlRain = "Consistent wet"))) %>%
  mutate(treatment=ordered(treatment, levels = c( consistentDry="consistentDry", fallDry="fallDry",springDry="springDry", controlRain="controlRain"))) %>%
  mutate(treatment = recode(treatment, consistentDry = "Consistent dry", fallDry = "Fall dry",  springDry = "Spring dry", controlRain = "Consistent wet")) %>%
  mutate(density = ordered(density, levels = c(D1 = "D1", D2 = "D2"))) %>%
  mutate(density = recode(density, D1 = "Low density", D2 = "High density"))

## BW version
p <- ggplot(subset(togdat2, species == "Avena" & R != 66), aes(x=(prop/10), y=(R)))+ geom_point(size = 2, color = "grey80")+ facet_grid(density~treatment,  scale="free") +
  geom_smooth(method="lm", color ="grey80", lwd = 1, se = F) + theme_bw() + ylab("Per capita population growth rate") + 
  geom_point(dat = subset(togdat2, species == "Erodium"), size = 2, color = "grey30") +
  geom_smooth(dat = subset(togdat2, species == "Erodium"), method="lm", color = "grey30", lwd = 1, se = F) +
  xlab("Seeding ratio")  + geom_hline(yintercept=1) + scale_x_continuous(limits = c(0, 1), breaks = c(.1, .5, .9, 1), labels = c(".1", ".5", ".9", "1")) + 
  theme(strip.background = element_blank(), text = element_text(size = 16), 
        strip.text.x = element_text(size = 16), strip.text.y = element_text(size = 16),
        panel.grid.major = element_blank(), panel.grid.minor = element_blank())
# ggsave(here("Figs", "fig1_avena-erodium-percapita.pdf"), width = 8, height = 6)
# ggsave(here("Figs", "fig1_avena-erodium-percapita.jpg"), width = 8, height = 6)

# add panel labels
g <- ggplotGrob(p)
#Use grid.text

pdf(here("Figs", "fig1.pdf"), width = 8, height = 5)
p
grid.text(c("(a)", "(b)", "(c)", "(d)", "(e)", "(f)", "(g)", "(h)"),x = c(0.26,0.48,.7,.925 ),
          y = c(rep(.89, 4), rep(.48, 4)),
          gp=gpar(fontsize=16))
dev.off()


## just letters no parantheses
# pdf(here("Figs", "fig1.pdf"), width = 8, height = 6)
# p
# grid.text(letters[1:8],x = c(0.09,0.31,.53,.76 ),y = c(rep(.91, 4), rep(.48, 4)),
#           gp=gpar(fontsize=16))
# dev.off()

## on the left
# pdf(here("Figs", "fig1.pdf"), width = 8, height = 6)
# p
# grid.text(c("(a)", "(b)", "(c)", "(d)", "(e)", "(f)", "(g)", "(h)"),x = c(0.09,0.31,.53,.752 ),
#           y = c(rep(.91, 4), rep(.48, 4)),
#           gp=gpar(fontsize=12))
# dev.off()




          