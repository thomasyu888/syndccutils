source("R/charts.R")
source("R/tables.R")
source("R/synapse_helpers.R")
source("R/processing.R")

library(dplyr)
library(purrr)
library(ggplot2)
library(viridis)
synLogin()
# Script/template to create summary tables and charts for a "project"
update_remote <- TRUE

# Config ------------------------------------------------------------------

synproject_id <- "syn9773346" # Synapse project for project Center
project_id <- "syn12558020" # Synapse folder associated with project
parent_id <- "syn11738516" # Center 'Reporting' folder where files should be stored
master_fileview_id <- "syn12677870" # Synapse fileview associated with project


# Collect data ------------------------------------------------------------

fileview_df <- get_table_df(master_fileview_id)

# Add Synapse project info --------------------------------------------

fileview_df <- fileview_df %>%
  left_join(summarize_project_info(.), by = "projectId")

# Data files by assay and tumor type --------------------------------------

table_filename <- glue::glue("{source_id}_DataFileCountsByAssayAndTumorType.html",
                             source_id = project_id)

# create and save table
group_keys <- c("assay", "sex")
count_cols <- c("id", "diagnosis", "individualID", "specimenID")

datafile_counts <- fileview_df %>%
  summarize_by_annotationkey(
    annotation_keys = group_keys,
    table_id = master_fileview_id,
    count_cols = count_cols
  )

datafile_counts_dt <- datafile_counts %>%
  format_summarytable_columns(group_keys) %>%
  as_datatable()

if (update_remote) {
  syn_dt_entity <- datafile_counts_dt %>%
     save_datatable(parent_id, table_filename, .)
}

# view table
datafile_counts_dt


# Individuals by assays and tumor type ------------------------------------

# chart_filename <- glue::glue("{source_id}_IndividualsByAssayAndTumorType.html",
#                              source_id = project_id)
# 
# # create and save chart
# plot_keys <- list(assay = "Assay", sex = "Sex", platform="Platform", dataType = "Data type")
# 
# chart <- fileview_df %>%
#   plot_sample_counts_by_annotationkey_2d(sample_key = "individualID",
#                                          annotation_keys = plot_keys)
# 
# if (update_remote) {
#   syn_chart_entity <- save_chart(parent_id, chart_filename, chart)
# }
# 
# # view chart
# chart


# Files by category -------------------------------------------------------

chart_filename <- glue::glue("{source_id}_DataFilesByCategory.html",
                             source_id = project_id)

# create and save chart
plot_keys <- list(assay = "Assay", tumorType = "Tumor Type",
                  projectName = "Study")

chart <- fileview_df %>%
  plot_file_counts_by_annotationkey(plot_keys, chart_height = 300)

if (update_remote) {
  # syn_entity <-
  save_chart(parent_id, chart_filename, chart)
}

# view chart
chart