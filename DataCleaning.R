# Load necessary libraries
library(readr)
library(readxl)
library(dplyr)
library(haven)   
library(lubridate)
#use this when you ant to describe and summarize your data
library(Hmisc)
#use this when you want to tabulate missing data.
library(naniar)
library(writexl)
library(tidyr)
library(openxlsx)
library(skimr)
library(janitor)
library(sparklyr)
library(anytime)
library(httr)


#reading data from kobocollect
#KP-COHOT REGISTER
token <- "e92d35776fbdcbe3a71080b3067e3efe181f754e"
data_url_csv <- "https://kf.kobotoolbox.org/api/v2/assets/aBJdpAdDaRYjQcJ2F6A5z9/export-settings/esWtsAJmEjvM4kmZ74BS46M/data.csv"
data_url_xlsx <- "https://kf.kobotoolbox.org/api/v2/assets/aBJdpAdDaRYjQcJ2F6A5z9/export-settings/esWtsAJmEjvM4kmZ74BS46M/data.xlsx"
# Make a GET request to download the CSV file
response_csv1 <-GET(data_url_xlsx, add_headers(Authorization = paste("Token", token)))
if (status_code(response_csv1) == 200) {
  # Read the CSV data into a data frame
  temp_file <- tempfile(fileext = ".xlsx")
  writeBin(content(response_csv1, as = "raw"), temp_file)
  
  # Read the XLSX data into a data frame
  kp_cohort <- read_excel(temp_file)

} else {
  print("Failed to download the CSV file.")
}
kp_cohort<-janitor::clean_names(kp_cohort)


#setting working directory
setwd("C:/Users/Admin/OneDrive - Kenya Red Cross Society/DATA MANAGEMENT/R/21-05-2024")
# define path to store data
path<-"C:/Users/Admin/OneDrive - Kenya Red Cross Society/DATA MANAGEMENT/R/21-05-2024/cleandata/"
today<-format(Sys.Date(),"%y-%m-%d")

#connect to spark
sc <- spark_connect(master = "local")
msm_ler<-spark_read
msm_ler <- spark_read_excel(sc, "LER/KP/MSM/MSM COnsolidated Q11.xlsx",sheet = "Sheet1",skip = 7)


#MSM CONSOLIFDATE COHOT REGISTER
# # 1. Lower easter region
msm_ler<-read_excel("LER/MSM/MSM Consolidated.xlsx",sheet = "Sheet1",skip = 7,col_types = "text") 
# msm_ler<- read.csv("LER/MSM/MSM Consolidated.csv")

#clean using janirot
msm_ler<-janitor::clean_names(msm_ler)
descriptive_ler<-skim(msm_ler)
# remove empty rows
msm_ler<-remove_empty(msm_ler,which = "rows")
#remove empty columns
msm_ler<-remove_empty(msm_ler,which = "cols")
#dups
msm_ler_dups<-get_dupes(msm_ler,kp_unique_identifier_sr_client_initials_typology_hotspot_pe_code_client_no)
# column_names <- colnames(msm_ler)
#changing numeric to dates

#tabulatin frequency

freq_nrr<- msm_ler %>% tabyl(sr_name)
freq_nrr <- freq_nrr %>%
  adorn_percentages("col") %>%
  adorn_pct_formatting(digits = 2) %>%
  adorn_ns()
print(freq_nrr)
table<-tabyl(consolidated_msm, county, region)
table<-table %>% adorn_totals("row") %>% adorn_totals("col")

#check if age is greater than 100
summary(msm_ler$age)
#check yob summary
summary(msm_ler$yob)

# Check for missing values
msm_ler_missing<-miss_var_cumsum(data = msm_ler)
msm_ler_missing_edate<-subset(msm_ler,is.na(date_of_enrolment_dd_mm_yyyy))
msm_ler_missing_edate<-select(msm_ler_missing_edate,sr_name,kp_unique_identifier_sr_client_initials_typology_hotspot_pe_code_client_no,date_of_first_contact_dd_mm_yyyy)
msm_ler_miss_contact_date<-subset(msm_ler,is.na(msm_ler$date_of_enrolment))
saveRDS(msm_ler_miss_contact_date,file = "MSM_MISSING_DATE_CONTACT.RDS")
write.csv(msm_ler_miss_contact_date,file="MSM_MISSING_DATE_CONTACT.csv")
write.csv(msm_ler,paste0(path,"msm_ler_",today,".csv"))

#2. NRR
msm_nrr<-read_excel("NRR/NRR MSM CONSOLIDATED Jan-June 2024.xlsx",sheet = "MSM",skip = 2, col_types = "text") 
msm_nrr<-janitor::clean_names(msm_nrr)
descriptive_nrr<-skim(msm_nrr)
# remove empty rows
msm_nrr<-remove_empty(msm_nrr,which = "rows")
#remove empty columns
msm_nrr<-remove_empty(msm_nrr,which = "cols")
#get duplicates
msm_nrr_dups<-get_dupes(msm_nrr,kp_unique_identifier_sr_client_initials_typology_hotspot_pe_code_client_no)
# column_names <- colnames(msm_nrr)
#tabulatin frequency

freq_nrr<- msm_nrr %>% tabyl(sr_name)
freq_nrr <- freq_nrr %>%
  adorn_percentages("col") %>%
  adorn_pct_formatting(digits = 2) %>%
  adorn_ns()
print(freq_nrr)

# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(msm_nrr)<-tolower(names(msm_nrr))
#check if age is greater than 100
summary(msm_nrr$age)
#check yob summary
summary(msm_nrr$yob)
# Check for missing values
msm_nrr_missing<-miss_var_cumsum(data = msm_nrr)
#consolidate nrr with ler
# check columns that are not matching
# msm_ler_cols<-setdiff(colnames(msm_ler),colnames(msm_nrr))
#Save MSMS
saveRDS(msm_nrr,file = paste0(path,"nrr_msm_cleandata_",today,".RDS"))
# print(msm_ler_cols)
names(msm_ler)<-names(msm_nrr)
consolidated_msm<-rbind(msm_ler,msm_nrr)


#3. WKR
msm_wkr<-read_excel("WKR/MSM/WKR_KP_Cohort Register_MSM.xlsx",sheet = "Register",skip = 4,col_types = "text") 
msm_wkr<-janitor::clean_names(msm_wkr)
descriptive_nrr<-skim(msm_wkr)
# remove empty rows
msm_wkr<-remove_empty(msm_wkr,which = "rows")
#remove empty columns
msm_wkr<-remove_empty(msm_wkr,which = "cols")
#get duplicates
msm_wkr_dups<-get_dupes(msm_wkr,kp_vp_unique_identifier_code_sr_client_initials_typology_hotspot_pe_code_client_no)
#tabulatin frequency

freq_nrr<- msm_wkr %>% tabyl(sr_name)
freq_nrr <- freq_nrr %>%
  adorn_percentages("col") %>%
  adorn_pct_formatting(digits = 2) %>%
  adorn_ns()
print(freq_nrr)

#check if age is greater than 100
summary(msm_wkr$age)
#check yob summary
summary(msm_wkr$yob)
# Check for missing values
msm_wkr_missing<-miss_var_cumsum(data = msm_wkr)
names(msm_wkr)<-names(consolidated_msm)
saveRDS(msm_wkr,file = paste0(path,"wkr_cleandata_",today,".RDS"))
consolidated_msm<-rbind(consolidated_msm,msm_wkr)

#cor
#4. COR
msm_cor<-read_excel("COR/COR_Consolidated MSM_Cohort Register- April 2024 (1).xlsx",sheet = "Register",skip = 7)
msm_cor<-read.csv("COR/COR_Consolidated MSM_Cohort Register- April 2024 (1).csv")
msm_cor<-janitor::clean_names(msm_cor)
descriptive_nrr<-skim(msm_cor)
# remove empty rows
msm_cor<-remove_empty(msm_cor,which = "rows")
#remove empty columns
msm_cor<-remove_empty(msm_cor,which = "cols")
msm_cor<-subset(msm_cor,kp_type!="")
#get duplicates
msm_cor_dups<-get_dupes(msm_cor,x_kp_unique_identifier_sr_client_initials_typology_hotspot_pe_code_client_no)
# column_names <- colnames(msm_cor)
#changing numeric to dates
msm_cor$date_of_next_appointment<- as.numeric(msm_cor$date_of_next_appointment)
msm_cor$date_of_next_appointment <- excel_numeric_to_date(msm_cor$date_of_next_appointment)
#tabulatin frequency

freq_nrr<- msm_cor %>% tabyl(sr_name)
freq_nrr <- freq_nrr %>%
  adorn_percentages("col") %>%
  adorn_pct_formatting(digits = 2) %>%
  adorn_ns()
print(freq_nrr)

# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(msm_cor)<-tolower(names(msm_cor))
#check if age is greater than 100
summary(msm_cor$age)
#check yob summary
summary(msm_cor$yob)
# Check for missing values
msm_cor_missing<-miss_var_cumsum(data = msm_cor)
names(msm_cor)<-names(consolidated_msm)
saveRDS(msm_cor,file = paste0(path,"cor_cleandata_",today,".RDS"))
consolidated_msm<-rbind(consolidated_msm,msm_cor)


#5. UER
msm_uer<-read_excel("UER/MSM/UER MSM Cohort register.xlsx",sheet = "Register",skip = 7,col_types = "text") 
msm_uer<-read.csv("UER/MSM/UER MSM Cohort register.csv")
msm_uer<-janitor::clean_names(msm_uer)
descriptive_nrr<-skim(msm_uer)
# remove empty rows
msm_uer<-remove_empty(msm_uer,which = "rows")
#remove empty columns
msm_uer<-remove_empty(msm_uer,which = "cols")
msm_uer<-subset(msm_uer,kp_type!="")
#get duplicates
msm_uer_dups<-get_dupes(msm_uer,kp_unique_identifier_sr_client_initials_typology_hotspot_pe_code_client_no)
#tabulatin frequency

freq_nrr<- msm_uer %>% tabyl(sr_name)
freq_nrr <- freq_nrr %>%
  adorn_percentages("col") %>%
  adorn_pct_formatting(digits = 2) %>%
  adorn_ns()
print(freq_nrr)
summary(msm_uer$age)
#check yob summary
summary(msm_uer$yob)
# Check for missing values
msm_uer_missing<-miss_var_cumsum(data = msm_uer)
names(msm_uer)<-names(consolidated_msm)
saveRDS(msm_uer,file = paste0(path,"uer_cleandata_",today,".RDS"))
consolidated_msm<-rbind(consolidated_msm,msm_uer)

#checking missing values in all dataset
condolidated_missing<-miss_var_cumsum(data = consolidated_msm)

#interchange the column for county and sr name where reegion is LER
consolidated_msm[consolidated_msm$region == "LER", c("sr_name", "county")] <- consolidated_msm[consolidated_msm$region == "LER", c("county", "sr_name")]
consolidated_msm[consolidated_msm$region == "UER", c("sr_name", "county")] <- consolidated_msm[consolidated_msm$region == "UER", c("county", "sr_name")]
consolidated_msm[consolidated_msm$region == "WKR", c("kp_type", "kp_unique_identifier_sr_client_initials_typology_hotspot_pe_code_client_no")] <- consolidated_msm[consolidated_msm$region == "WKR", c("kp_unique_identifier_sr_client_initials_typology_hotspot_pe_code_client_no", "kp_type")]
#change all columns to lower case
consolidated_msm <- data.frame(lapply(consolidated_msm, function(x) {
  if (is.character(x)) {
    return(tolower(x))
  } else {
    return(x)
  }
}), stringsAsFactors = FALSE)

#change county names to uppercase
consolidated_msm$county<-toupper(consolidated_msm$county)
consolidated_msm$hiv_status<-tolower(consolidated_msm$hiv_status)
consolidated_msm$hiv_care_outcome<-tolower(consolidated_msm$hiv_care_outcome)
write.csv(consolidated_msm,file = paste0(path,"consolidated_msm_june_",today,".csv"))
saveRDS(consolidated_msm,file = paste0(path,"consolidated_msm_april_",today,"RDS"))

#PWID packages
#Tested for HIV
msm_hivtest_counts <- msm_consolidated %>%
  summarise(across(starts_with("tested_for_hiv"), ~ sum(. == "Yes", na.rm = TRUE)))

print(msm_hivtest_counts)
#Initiated on PREP
msm_PREP_counts <- msm_consolidated %>%
  summarise(across(starts_with("initiated_on_prep"), ~ sum(. == "Yes", na.rm = TRUE)))

print(msm_PREP_counts)
#Defined package
screened_for_sti<-msm_consolidated %>%
  mutate(
    combo_condition = (screened_for_stis61 == "Yes" | screened_for_stis114 == "Yes" |  screened_for_stis167 == "Yes")
                         
  )
combo_count_sti <- screened_for_sti %>%
  summarise(jan_to_march = sum(combo_condition, na.rm = TRUE))


received_peer_education<-msm_consolidated %>%
  mutate(
    combo_condition = (received_peer_education22 == "Yes" | received_peer_education75 == "Yes" | received_peer_education128 == "Yes")
    
  )
combo_count_peer <- received_peer_education %>%
  summarise(jan_to_march = sum(combo_condition, na.rm = TRUE))


rssh<-msm_consolidated %>%
  mutate(
    combo_condition = (provided_with_risk_reduction_couselling68 == "Yes" | provided_with_risk_reduction_couselling121 == "Yes" | provided_with_risk_reduction_couselling174 == "Yes")
    
  )
combo_count_rssh <- rssh %>%
  summarise(jan_to_march = sum(combo_condition, na.rm = TRUE))

condom_distribution<-msm_consolidated %>%
  mutate(
    combo_condition = ( condoms_distributed_nmbr46 > 0|  condoms_distributed_nmbr99 > 0 |  condoms_distributed_nmbr152 > 0)
    
  )
combo_count_condom <- condom_distribution %>%
  summarise(jan_to_march = sum(combo_condition, na.rm = TRUE))


combined <- msm_consolidated %>%
  mutate(
    combo_condition = (screened_for_stis61 == "Yes" | 
                         screened_for_stis114 == "Yes" |  
                         screened_for_stis167 == "Yes") & 
      ( # Add other screened_for_sti variables here
      (received_peer_education22 == "Yes" |
         received_peer_education75 == "Yes" | 
         received_peer_education128 == "Yes") |
      (provided_with_risk_reduction_couselling68 == "Yes" |
         provided_with_risk_reduction_couselling121 == "Yes" | 
         provided_with_risk_reduction_couselling174 == "Yes")) &
      (condoms_distributed_nmbr46 > 0 |
         condoms_distributed_nmbr99 > 0 | 
         condoms_distributed_nmbr152 > 0)
  ) %>%
  summarise(
    jan_to_march = sum(combo_condition, na.rm = TRUE)
  )

print(combined)



msm_definedPackageCounts <- msm_consolidated %>%
  mutate(
    combo_condition = (screened_for_stis61 == "Yes" & 
                         (provided_with_risk_reduction_couselling68 == "Yes" | received_peer_education22 == "Yes") &
                         condoms_distributed_nmbr46 > 0) |
      (screened_for_stis114 == "Yes" & 
         (provided_with_risk_reduction_couselling121 == "Yes" | received_peer_education75 == "Yes") &
         condoms_distributed_nmbr99 > 0) |
      (screened_for_stis167 == "Yes" & 
         (provided_with_risk_reduction_couselling174 == "Yes" | received_peer_education128 == "Yes") &
         condoms_distributed_nmbr152 > 0)
  )

# Count the number of rows meeting the combined condition
combo_count <- msm_definedPackageCounts %>%
  summarise(jan_to_march = sum(combo_condition, na.rm = TRUE))












#FSW CONSOLIFDATE COHOT REGISTER
# # 1. Lower easter region
fsw_ler<-read_excel("LER/KP/FSW/FSW Consolidated Q11.xlsx",sheet = "Sheet1",skip = 7) 
# column_names <- colnames(fsw_ler)
# print(column_names)
# converting the columns to be separated by underscore
colnames(fsw_ler) <- gsub(" ", "_", colnames(fsw_ler))
colnames(fsw_ler) <- gsub("-", "_", colnames(fsw_ler))
#delete duplicates with no entries
fsw_ler<-subset(fsw_ler,KP_Type!="")
#removing unwanyed characters
colnames(fsw_ler) <- gsub("[<(.)/>]", "", colnames(fsw_ler))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(fsw_ler)<-tolower(names(fsw_ler))
fsw_ler <- fsw_ler %>%
  rename(kp_unique_identifier = "kp_unique_identifier\r\nsrclient_initialstypologyhotspotpe_codeclient_no")
fsw_ler<-fsw_ler %>% rename(date_of_enrolment="date_of_enrolment_ddmmyyyy")
fsw_ler<-fsw_ler %>% rename(date_of_first_contact="date_of_first_contact_ddmmyyyy")
fsw_ler<-fsw_ler %>% rename(date_of_next_appointment73="date_of_next_appointment\r\ndd_mm_yyyy_eg_02_may_201873")
fsw_ler<-fsw_ler %>% rename(date_of_next_appointment126="date_of_next_appointment\r\ndd_mm_yyyy_eg_02_may_2018126")
fsw_ler<- select(fsw_ler,-a)

#check if age is greater than 100
summary(fsw_ler$age)
#check yob summary
summary(fsw_ler$yob)
# check for duplictes using kp unique identifier
fsw_ler_duplicates<-fsw_ler[duplicated(fsw_ler$kp_unique_identifier),]
# Check for missing values
fsw_ler_missing<-miss_var_cumsum(data = fsw_ler)
fsw_ler_miss_contact_date<-subset(fsw_ler,is.na(fsw_ler$date_of_first_contact))
saveRDS(fsw_ler_missing,file = "FSW_MISSING_DATE_CONTACT.RDS")
write.csv(fsw_ler_missing,file="FSW_MISSING_DATE_CONTACT.csv")


#2 NRR
fsw_nrr<-read_excel("NRR/NRR FSW CONSOLIDATED Jan-June 2024.xlsx",sheet = "FSW",skip = 2) 
# column_names <- colnames(fsw_nrr)
# print(column_names)
# converting the columns to be separated by underscore
colnames(fsw_nrr) <- gsub(" ", "_", colnames(fsw_nrr))
colnames(fsw_nrr) <- gsub("-", "_", colnames(fsw_nrr))
#delete duplicates with no entries
fsw_nrr<-subset(fsw_nrr,KP_Type!="")
#removing unwanyed characters
colnames(fsw_nrr) <- gsub("[<(.)/>]", "", colnames(fsw_nrr))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(fsw_nrr)<-tolower(names(fsw_nrr))
fsw_nrr <- fsw_nrr %>%
  rename(kp_unique_identifier = "kp_unique_identifier\r\nsrclient_initialstypologyhotspotpe_codeclient_no")
fsw_nrr<-fsw_nrr %>% rename(date_of_enrolment="date_of_enrolment_ddmmyyyy")
fsw_nrr<-fsw_nrr %>% rename(date_of_first_contact="date_of_first_contact_ddmmyyyy")
names(fsw_nrr)<-names(fsw_ler)

#check if age is greater than 100
summary(fsw_nrr$age)
#check yob summary
summary(fsw_nrr$yob)
# check for duplictes using kp unique identifier
fsw_nrr_duplicates<-fsw_nrr[duplicated(fsw_nrr$kp_unique_identifier),]
# Check for missing values
fsw_nrr_missing<-miss_var_cumsum(data = fsw_nrr)
fsw_nrr_miss_contact_date<-subset(fsw_nrr,is.na(fsw_nrr$date_of_first_contact))
saveRDS(fsw_nrr_missing,file = "FSW_MISSING_DATE_CONTACT.RDS")
write.csv(fsw_nrr_missing,file="FSW_MISSING_DATE_CONTACT.csv")

#merge
consolidated_fsw<-rbind(fsw_ler,fsw_nrr)

#3. wkr
fsw_wkr<-read_excel("WKR/KP/Cohorts/WKR_KP_Cohort Register_FSW.xlsx",sheet = "Register",skip = 7) 
# column_names <- colnames(fsw_wkr)
# print(column_names)
# converting the columns to be separated by underscore
colnames(fsw_wkr) <- gsub(" ", "_", colnames(fsw_wkr))
colnames(fsw_wkr) <- gsub("-", "_", colnames(fsw_wkr))
#delete duplicates with no entries
fsw_wkr<-subset(fsw_wkr,KP_Type!="")
#removing unwanyed characters
colnames(fsw_wkr) <- gsub("[<(.)/>]", "", colnames(fsw_wkr))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(fsw_wkr)<-tolower(names(fsw_wkr))
fsw_wkr <- fsw_wkr %>%
  rename(kp_unique_identifier = "kp_unique_identifier\r\nsrclient_initialstypologyhotspotpe_codeclient_no")
fsw_wkr<-fsw_wkr %>% rename(date_of_enrolment="date_of_enrolment_ddmmyyyy")
fsw_wkr<-fsw_wkr %>% rename(date_of_first_contact="date_of_first_contact_ddmmyyyy")


#check if age is greater than 100
summary(fsw_wkr$age)
#check yob summary
summary(fsw_wkr$yob)
# check for duplictes using kp unique identifier
fsw_wkr_duplicates<-fsw_wkr[duplicated(fsw_wkr$kp_unique_identifier),]
names(fsw_wkr)<-names(consolidated_fsw)
# Check for missing values
fsw_wkr_missing<-miss_var_cumsum(data = fsw_wkr)
fsw_wkr_miss_contact_date<-subset(fsw_wkr,is.na(fsw_wkr$date_of_first_contact))
saveRDS(fsw_wkr_missing,file = "FSW_MISSING_DATE_CONTACT.RDS")

#merge and consolidate
consolidated_fsw<-rbind(consolidated_fsw,fsw_wkr)

#4. COR
fsw_cor<-read_excel("COR/FSW/COR_Consolidated FSW_Cohort Register- Jan-Mar 2024.xlsx",sheet = "Register",skip = 7) 
# column_names <- colnames(fsw_cor)
# print(column_names)
# converting the columns to be separated by underscore
colnames(fsw_cor) <- gsub(" ", "_", colnames(fsw_cor))
colnames(fsw_cor) <- gsub("-", "_", colnames(fsw_cor))
#delete duplicates with no entries
fsw_cor<-subset(fsw_cor,KP_Type!="")
#removing unwanyed characters
colnames(fsw_cor) <- gsub("[<(.)/>]", "", colnames(fsw_cor))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(fsw_cor)<-tolower(names(fsw_cor))
fsw_cor <- fsw_cor %>%
  rename(kp_unique_identifier = "kp_unique_identifier\r\nsrclient_initialstypologyhotspotpe_codeclient_no")
fsw_cor<-fsw_cor %>% rename(date_of_enrolment="date_of_enrolment_ddmmyyyy")
fsw_cor<-fsw_cor %>% rename(date_of_first_contact="date_of_first_contact_ddmmyyyy")


#check if age is greater than 100
summary(fsw_cor$age)
#check yob summary
summary(fsw_cor$yob)
# check for duplictes using kp unique identifier
fsw_cor_duplicates<-fsw_cor[duplicated(fsw_cor$kp_unique_identifier),]
fsw_cor_duplicates_kp<-fsw_cor[duplicated(fsw_cor$`KP's_Name(3_Names_&_Nickname)`),]
names(fsw_cor)<-names(consolidated_fsw)
# Check for missing values
fsw_cor_missing<-miss_var_cumsum(data = fsw_cor)
fsw_cor_miss_contact_date<-subset(fsw_cor,is.na(fsw_cor$date_of_first_contact))
saveRDS(fsw_cor_miss_contact_date,file = "FSW_MISSING_DATE_CONTACT.RDS")
write.csv(fsw_cor_miss_contact_date,file = "FSW_MISSING_DATE_CONTACT.csv")

#merge and consolidate
consolidated_fsw<-rbind(fsw_cor,consolidated_fsw)

#5. UER
fsw_uer<-read_excel("UER/UER FSW Cohort Register.xlsx",sheet = "Register",skip = 7) 
# column_names <- colnames(fsw_uer)
# print(column_names)
# converting the columns to be separated by undersuere
colnames(fsw_uer) <- gsub(" ", "_", colnames(fsw_uer))
colnames(fsw_uer) <- gsub("-", "_", colnames(fsw_uer))
#delete duplicates with no entries
fsw_uer<-subset(fsw_uer,KP_Type!="")
#removing unwanyed characters
colnames(fsw_uer) <- gsub("[<(.)/>]", "", colnames(fsw_uer))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(fsw_uer)<-tolower(names(fsw_uer))
fsw_uer <- fsw_uer %>%
  rename(kp_unique_identifier = "kp_unique_identifier\r\nsrclient_initialstypologyhotspotpe_codeclient_no")
fsw_uer<-fsw_uer %>% rename(date_of_enrolment="date_of_enrolment_ddmmyyyy")
fsw_uer<-fsw_uer %>% rename(date_of_first_contact="date_of_first_contact_ddmmyyyy")


#check if age is greater than 100
summary(fsw_uer$age)
#check yob summary
summary(fsw_uer$yob)
# check for duplictes using kp unique identifier
fsw_uer_duplicates<-fsw_uer[duplicated(fsw_uer$kp_unique_identifier),]
#drop duplicates
fsw_uer<-fsw_uer[!duplicated(fsw_uer$kp_unique_identifier),]
names(fsw_uer)<-names(consolidated_fsw)
# Check for missing values
fsw_uer_missing<-miss_var_cumsum(data = fsw_uer)
fsw_uer_miss_contact_date<-subset(fsw_uer,is.na(fsw_uer$date_of_first_contact))
saveRDS(fsw_uer_miss_contact_date,file = "FSW_MISSING_DATE_CONTACT.RDS")
write.csv(fsw_uer_miss_contact_date,file = "FSW_MISSING_DATE_CONTACT.csv")

#merge and consolidate
consolidated_fsw<-rbind(consolidated_fsw,fsw_uer)

#5. NER
fsw_ner<-read_excel("NER/NER Consolidated FSW Cohort Register Jan - March 2024.xlsx",sheet = "Register",skip = 4) 
# column_names <- colnames(fsw_ner)
# print(column_names)
# converting the columns to be separated by undersnere
colnames(fsw_ner) <- gsub(" ", "_", colnames(fsw_ner))
colnames(fsw_ner) <- gsub("-", "_", colnames(fsw_ner))
#delete duplicates with no entries
fsw_ner<-subset(fsw_ner,KP_Type!="")
#removing unwanyed characters
colnames(fsw_ner) <- gsub("[<(.)/>]", "", colnames(fsw_ner))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(fsw_ner)<-tolower(names(fsw_ner))
fsw_ner <- fsw_ner %>%
  rename(kp_unique_identifier = "kp_unique_identifier\r\nsrclient_initialstypologyhotspotpe_codeclient_no")
fsw_ner<-fsw_ner %>% rename(date_of_enrolment="date_of_enrolment_ddmmyyyy")
fsw_ner<-fsw_ner %>% rename(date_of_first_contact="date_of_first_contact_ddmmyyyy")


#check if age is greater than 100
summary(fsw_ner$age)
#check yob summary
summary(fsw_ner$yob)
# check for duplictes using kp unique identifier
fsw_ner_duplicates<-fsw_ner[duplicated(fsw_ner$kp_unique_identifier),]
#drop duplicates
fsw_ner<-fsw_ner[!duplicated(fsw_ner$kp_unique_identifier),]
names(fsw_ner)<-names(consolidated_fsw)
# Check for missing values
fsw_ner_missing<-miss_var_cumsum(data = fsw_ner)
fsw_ner_miss_contact_date<-subset(fsw_ner,is.na(fsw_ner$date_of_first_contact))
saveRDS(fsw_ner_miss_contact_date,file = "FSW_MISSING_DATE_CONTACT.RDS")
write.csv(fsw_ner_miss_contact_date,file = "FSW_MISSING_DATE_CONTACT.csv")

#merge and consolidate
consolidated_fsw<-rbind(consolidated_fsw,fsw_ner)

#export to csv and rds
write.csv(consolidated_fsw,file = paste0(path,"Consolidated_fsw_",today,'.csv'))
saveRDS(consolidated_fsw,file = paste0(path,"Consolidated_fsw_",today,'RDS'))




#switch counties and sr name
consolidated_fsw <- consolidated_fsw %>%
  mutate(
    # Create a new column to store the swapped values
    swapped_value = ifelse(region == "COR", county, sr_name),
    # Swap values between county and sr_name where region is "nrr"
    county = ifelse(region == "COR", sr_name, county),
    sr_name = swapped_value
  ) %>%
  select(-swapped_value)




#PWID
pwid_ler<-read_excel("LER/KP/PWID/PWID COnsolidated.xlsx",sheet = "Sheet1",skip = 7) 
# column_names <- colnames(pwid_ler)
# print(column_names)
# converting the columns to be separated by underscore
colnames(pwid_ler) <- gsub(" ", "_", colnames(pwid_ler))
colnames(pwid_ler) <- gsub("-", "_", colnames(pwid_ler))
#delete duplicates with no entries
pwid_ler<-subset(pwid_ler,KP_Type!="")
#removing unwanyed characters
colnames(pwid_ler) <- gsub("[<(.)/>]", "", colnames(pwid_ler))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(pwid_ler)<-tolower(names(pwid_ler))
pwid_ler <- pwid_ler %>%
  rename(kp_unique_identifier = "kp_unique_identifier\r\nsrclient_initialstypologyhotspotpe_codeclient_no")
pwid_ler<-pwid_ler %>% rename(date_of_enrolment="date_of_enrolment_ddmmyyyy")
pwid_ler<-pwid_ler %>% rename(date_of_first_contact="date_of_first_contact_ddmmyyyy")
pwid_ler<-pwid_ler %>% rename(date_of_next_appointment73="date_of_next_appointment\r\ndd_mm_yyyy_eg_02_may_201873")
pwid_ler<-pwid_ler %>% rename(date_of_next_appointment126="date_of_next_appointment\r\ndd_mm_yyyy_eg_02_may_2018126")
pwid_ler<- select(pwid_ler,-a)

#check if age is greater than 100
summary(pwid_ler$age)
#check yob summary
summary(pwid_ler$yob)
# check for duplictes using kp unique identifier
pwid_ler_duplicates<-pwid_ler[duplicated(pwid_ler$kp_unique_identifier),]
# Check for missing values
pwid_ler_missing<-miss_var_cumsum(data = pwid_ler)
pwid_ler_miss_contact_date<-subset(pwid_ler,is.na(pwid_ler$date_of_enrolment))
saveRDS(pwid_ler_miss_contact_date,file = "pwid_MISSING_DATE_CONTACT.RDS")
write.csv(pwid_ler_miss_contact_date,file="pwid_MISSING_DATE_CONTACT.csv")
write.csv(pwid_ler,paste0(path,"pwid_ler_",today,".csv"))

#2. NRR
pwid_nrr<-read_excel("NRR/NRR PWID CONSOLIDATED Jan-June 2024.xlsx",sheet = "PWID",skip = 2) 
# column_names <- colnames(pwid_nrr)
# print(column_names)
# converting the columns to be separated by underscore
colnames(pwid_nrr) <- gsub(" ", "_", colnames(pwid_nrr))
colnames(pwid_nrr) <- gsub("-", "_", colnames(pwid_nrr))
#delete duplicates with no entries
pwid_nrr<-subset(pwid_nrr,KP_Type!="")
#removing unwanyed characters
colnames(pwid_nrr) <- gsub("[<(.)/>]", "", colnames(pwid_nrr))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(pwid_nrr)<-tolower(names(pwid_nrr))
pwid_nrr <- pwid_nrr %>%
  rename(kp_unique_identifier = "kp_unique_identifier\r\nsrclient_initialstypologyhotspotpe_codeclient_no")
#check if age is greater than 100
summary(pwid_nrr$age)
#check yob summary
summary(pwid_nrr$yob)
# check for duplictes using kp unique identifier
pwid_nrr_duplicates<-pwid_nrr[duplicated(pwid_nrr$kp_unique_identifier),]
# Check for missing values
pwid_nrr_missing<-miss_var_cumsum(data = pwid_nrr)
#consolidate nrr with ler
# check columns that are not matching
# pwid_ler_cols<-setdiff(colnames(pwid_ler),colnames(pwid_nrr))
# print(pwid_ler_cols)
names(pwid_ler)<-names(pwid_nrr)
consolidated_pwid<-rbind(pwid_ler,pwid_nrr)
pwid_nrr$date_of_first_contact <- as.Date(pwid_nrr$date_of_first_contact)
pwid_ler$date_of_first_contact <- as.Date(pwid_ler$date_of_first_contact)
pwid_nrr$date_of_enrolment <- as.Date(pwid_nrr$date_of_enrolment)
pwid_ler$date_of_enrolment <- as.Date(pwid_ler$date_of_enrolment)
pwid_nrr$`date_of_next_appointment
dd_mm_yyyy_eg_02_may_201873` <- as.Date(pwid_nrr$date_of_enrolment)
pwid_ler$date_of_enrolment <- as.Date(pwid_ler$date_of_enrolment)

consolidated_pwid<-bind_rows(pwid_ler,pwid_nrr)


#3. WKR
pwid_wkr<-read_excel("WKR/KP/Cohorts/WKR_KP_Cohort Register_PWID.xlsx",sheet = "Register",skip = 7) 
colnames(pwid_wkr) <- gsub(" ", "_", colnames(pwid_wkr))
colnames(pwid_wkr) <- gsub("-", "_", colnames(pwid_wkr))
#delete duplicates with no entries
pwid_wkr<-subset(pwid_wkr,KP_Type!="")
#removing unwanyed characters
colnames(pwid_wkr) <- gsub("[<(.)/>]", "", colnames(pwid_wkr))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(pwid_wkr)<-tolower(names(pwid_wkr))
pwid_wkr<-select(pwid_wkr,-a)
#check if age is greater than 100
summary(pwid_wkr$age)
#check yob summary
summary(pwid_wkr$yob)
names(pwid_wkr)<-names(pwid_nrr)
# check for duplictes using kp unique identifier
pwid_wkr_duplicates<-pwid_wkr[duplicated(pwid_wkr$kp_unique_identifier),]
# Check for missing values
pwid_wkr_missing<-miss_var_cumsum(data = pwid_wkr)
#consolidate nrr with ler
# check columns that are not matching
names(pwid_wkr)<-names(consolidated_pwid)
pwid_ler_cols<-setdiff(colnames(pwid_ler),colnames(pwid_wkr))
print(pwid_ler_cols)
consolidated_pwid<-rbind(pwid_wkr,consolidated_pwid)
write.csv(pwid_wkr,file = paste0(path,"wkr_pwid_",today,"_.csv"))

#cor
#4. COR
pwid_cor<-read_excel("COR/PWID/PWID/COR_Consolidated PWID_Cohort Register- Jan- Mar 2024.xlsx",sheet = "Register",skip = 7) 
colnames(pwid_cor) <- gsub(" ", "_", colnames(pwid_cor))
colnames(pwid_cor) <- gsub("-", "_", colnames(pwid_cor))
#delete duplicates with no entries
pwid_cor<-subset(pwid_cor,KP_Type!="")
#removing unwanyed characters
colnames(pwid_cor) <- gsub("[<(.)/>]", "", colnames(pwid_cor))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(pwid_cor)<-tolower(names(pwid_cor))
pwid_cor<-select(pwid_cor,-a)
#check if age is greater than 100
summary(pwid_cor$age)
#check yob summary
summary(pwid_cor$yob)
names(pwid_cor)<-names(pwid_nrr)
# check for duplictes using kp unique identifier
pwid_cor_duplicates<-pwid_cor[duplicated(pwid_cor$kp_unique_identifier),]
# Check for missing values
pwid_cor_missing<-miss_var_cumsum(data = pwid_cor)
pwid_cor_missing_date_enrol<-subset(pwid_cor,is.na(pwid_cor$date_of_enrolment))
write.csv(pwid_cor_missing_date_enrol,file = "pwid_cor_missing_date_enrol.csv")
write.csv(pwid_cor,file = paste0(path,"cor_pwid_",today,"_.csv"))
#consolidate nrr with ler
# check columns that are not matching
# pwid_cor_cols<-setdiff(colnames(pwid_cor),colnames(pwid_nrr))
# print(pwid_cor_cols)

#5. UER
pwid_uer<-read_excel("UER/UER PWID Cohort register.xlsx",sheet = "Register",skip = 7) 
colnames(pwid_uer) <- gsub(" ", "_", colnames(pwid_uer))
colnames(pwid_uer) <- gsub("-", "_", colnames(pwid_uer))
#delete duplicates with no entries
pwid_uer<-subset(pwid_uer,KP_Type!="")
#removing unwanyed characters
colnames(pwid_uer) <- gsub("[<(.)/>]", "", colnames(pwid_uer))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(pwid_uer)<-tolower(names(pwid_uer))
pwid_uer<-select(pwid_uer,-a)
names(pwid_uer)<-names(pwid_nrr)
#check if age is greater than 100
summary(pwid_uer$age)
#check yob summary
summary(pwid_uer$yob)


# check for duplictes using kp unique identifier
pwid_uer_duplicates<-pwid_uer[duplicated(pwid_uer$kp_unique_identifier),]
# Check for missing values
pwid_uer_missing<-miss_var_cumsum(data = pwid_uer)
#consolidate data
consolidated_cor_uer<-rbind(pwid_cor,pwid_uer)
consolidated_pwid<-rbind(consolidated_cor_uer,consolidated_pwid)
#checking for mising values in consolidated data
consolidated_missing<-miss_var_cumsum(data = consolidated_pwid)
#SAVE consolidated data
write.csv(consolidated_pwid,file = paste0(path,"Consolidated_pwid_",today,".csv"))
saveRDS(consolidated_pwid,paste0(path,"Consolidated_pwid_",today,".RDS"))
write.xlsx(consolidated_pwid,paste0(path,"Consolidated_pwid_",today,".xlsx"))
# Compress the CSV file using gzip
system(paste("gzip", paste0(path, "Consolidated_pwid_", today, ".csv")))

pwid_consolidated<-rbind(pwid_uer,pwid_nrr)
write.csv(pwid_consolidated,file = paste0(path,"pwid_Conoslidated_",today,"_.csv"))

#readin consolidated data
pwid_consolidated<-read.csv("cleandata/pwid_Conoslidated_24-04-12_.csv")
#check duplicates
pwid_consolidated_duplicates<-pwid_consolidated[duplicated(pwid_consolidated$kp_unique_identifier),]
consolidated_missing<-miss_var_cumsum(data = pwid_consolidated)

#5. NER
pwid_ner<-read_excel("NER/NER Consolidated PWID Cohort Register Jan - March 2024.xlsx",sheet = "Register",skip = 4) 
colnames(pwid_ner) <- gsub(" ", "_", colnames(pwid_ner))
colnames(pwid_ner) <- gsub("-", "_", colnames(pwid_ner))
#delete duplicates with no entries
pwid_ner<-subset(pwid_ner,KP_Type!="")
#removing unwanyed characters
colnames(pwid_ner) <- gsub("[<(.)/>]", "", colnames(pwid_ner))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(pwid_ner)<-tolower(names(pwid_ner))
names(pwid_ner)<-names(pwid_nrr)
#check if age is greater than 100
summary(pwid_ner$age)
#check yob summary
summary(pwid_ner$yob)


# check for duplictes using kp unique identifier
pwid_ner_duplicates<-pwid_ner[duplicated(pwid_ner$kp_unique_identifier),]
# Check for missing values
pwid_ner_missing<-miss_var_cumsum(data = pwid_ner)
#consolidate data
consolidated_cor_ner<-rbind(pwid_wkr,pwid_ner)
consolidated_pwid<-rbind(pwid_ner,consolidated_pwid)
#checking for mising values in consolidated data
consolidated_missing<-miss_var_cumsum(data = consolidated_pwid)
#SAVE consolidated data
write.csv(consolidated_pwid,file = paste0(path,"Consolidated_pwid_",today,".csv"))
saveRDS(consolidated_pwid,paste0(path,"Consolidated_pwid_",today,".RDS"))
write.xlsx(consolidated_pwid,paste0(path,"Consolidated_pwid_",today,".xlsx"))
# Compress the CSV file using gzip
system(paste("gzip", paste0(path, "Consolidated_pwid_", today, ".csv")))

pwid_consolidated<-rbind(pwid_ner,pwid_nrr)
write.csv(consolidated_pwid,file = paste0(path,"consolidated_pwid",today,"_.csv"))

#readin consolidated data
pwid_consolidated<-read.csv("cleandata/consolidated_pwid24-04-12_.csv")
#check duplicates
pwid_consolidated_duplicates<-pwid_consolidated[duplicated(pwid_consolidated$kp_unique_identifier),]
consolidated_pwid_missing<-miss_var_cumsum(data = pwid_consolidated)
saveRDS(pwid_consolidated,file =paste0(path,"PWID_Consolidated_",today,".RDS"))
write.csv(pwid_consolidated,file =paste0(path,"PWID_Consolidated_",today,".csv"))

#PWID packages
#Tested for HIV
pwid_hivtest_counts <- pwid_consolidated %>%
  summarise(across(starts_with("tested_for_hiv"), ~ sum(. == "Yes", na.rm = TRUE)))

print(pwid_hivtest_counts)





#TG
#NRR
tg_nrr<-read_excel("NRR/NRR TG CONSOLIDATED Jan-June 2024.xlsx",sheet = "TG",skip = 2) 
# column_names <- colnames(tg_nrr)
# print(column_names)
# converting the columns to be separated by underscore
colnames(tg_nrr) <- gsub(" ", "_", colnames(tg_nrr))
colnames(tg_nrr) <- gsub("-", "_", colnames(tg_nrr))
#delete duplicates with no entries
tg_nrr<-subset(tg_nrr,KP_Type!="")
#removing unwanyed characters
colnames(tg_nrr) <- gsub("[<(.)/>]", "", colnames(tg_nrr))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(tg_nrr)<-tolower(names(tg_nrr))
tg_nrr <- tg_nrr %>%
  rename(kp_unique_identifier = "kp_unique_identifier\r\nsrclient_initialstypologyhotspotpe_codeclient_no")
#check if age is greater than 100
summary(tg_nrr$age)
#check yob summary
summary(tg_nrr$yob)
# check for duplictes using kp unique identifier
tg_nrr_duplicates<-tg_nrr[duplicated(tg_nrr$kp_unique_identifier),]
# Check for missing values
tg_nrr_missing<-miss_var_cumsum(data = tg_nrr)
#consolidate nrr with ler
# check columns that are not matching
# tg_ler_cols<-setdiff(colnames(tg_ler),colnames(tg_nrr))
# print(tg_ler_cols)
names(tg_ler)<-names(tg_nrr)
consolidated_tg<-rbind(tg_ler,tg_nrr)

#2 UER
tg_uer<-read_excel("UER/UER TG Cohort register.xlsx",sheet = "Register",skip = 7) 
# column_names <- colnames(tg_uer)
# print(column_names)
# converting the columns to be separated by underscore
colnames(tg_uer) <- gsub(" ", "_", colnames(tg_uer))
colnames(tg_uer) <- gsub("-", "_", colnames(tg_uer))
#delete duplicates with no entries
tg_uer<-subset(tg_uer,KP_Type!="")
#removing unwanyed characters
colnames(tg_uer) <- gsub("[<(.)/>]", "", colnames(tg_uer))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(tg_uer)<-tolower(names(tg_uer))
tg_uer <- tg_uer %>%
  rename(kp_unique_identifier = "kp_unique_identifier\r\nsrclient_initialstypologyhotspotpe_codeclient_no")
#check if age is greater than 100
summary(tg_uer$age)
#check yob summary
summary(tg_uer$yob)
# check for duplictes using kp unique identifier
tg_uer_duplicates<-tg_uer[duplicated(tg_uer$kp_unique_identifier),]
# Check for missing values
tg_uer_missing<-miss_var_cumsum(data = tg_uer)
#consolidate uer with ler
# check columns that are not matching
# tg_ler_cols<-setdiff(colnames(tg_ler),colnames(tg_uer))
# print(tg_ler_cols)
names(tg_uer)<-names(tg_nrr)
consolidated_tg<-rbind(tg_nrr,tg_uer)


#3 COR
tg_cor<-read_excel("COR/Trans/COR_Consolidated TGs Cohort Register-Jan-Mar 2024.xlsx",sheet = "Register",skip = 7) 
# column_names <- colnames(tg_cor)
# print(column_names)
# converting the columns to be separated by underscore
colnames(tg_cor) <- gsub(" ", "_", colnames(tg_cor))
colnames(tg_cor) <- gsub("-", "_", colnames(tg_cor))
#delete duplicates with no entries
tg_cor<-subset(tg_cor,KP_Type!="")
#removing unwanyed characters
colnames(tg_cor) <- gsub("[<(.)/>]", "", colnames(tg_cor))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(tg_cor)<-tolower(names(tg_cor))
tg_cor <- tg_cor %>%
  rename(kp_unique_identifier = "kp_unique_identifier\r\nsrclient_initialstypologyhotspotpe_codeclient_no")
#check if age is greater than 100
summary(tg_cor$age)
#check yob summary
summary(tg_cor$yob)
# check for duplictes using kp unique identifier
tg_cor_duplicates<-tg_cor[duplicated(tg_cor$kp_unique_identifier),]
# Check for missing values
tg_cor_missing<-miss_var_cumsum(data = tg_cor)
#consolidate cor with ler
# check columns that are not matching
# tg_ler_cols<-setdiff(colnames(tg_ler),colnames(tg_cor))
# print(tg_ler_cols)
names(tg_cor)<-names(consolidated_tg)
consolidated_tg<-rbind(tg_cor,consolidated_tg)


#4 WKR
tg_wkr<-read_excel("WKR/KP/Cohorts/WKR_KP_Cohort Register_TG.xlsx",sheet = "Register",skip = 7) 
# column_names <- colnames(tg_wkr)
# print(column_names)
# converting the columns to be separated by underswkre
colnames(tg_wkr) <- gsub(" ", "_", colnames(tg_wkr))
colnames(tg_wkr) <- gsub("-", "_", colnames(tg_wkr))
#delete duplicates with no entries
tg_wkr<-subset(tg_wkr,KP_Type!="")
#removing unwanyed characters
colnames(tg_wkr) <- gsub("[<(.)/>]", "", colnames(tg_wkr))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(tg_wkr)<-tolower(names(tg_wkr))
tg_wkr <- tg_wkr %>%
  rename(kp_unique_identifier = "kp_unique_identifier\r\nsrclient_initialstypologyhotspotpe_codeclient_no")
#check if age is greater than 100
summary(tg_wkr$age)
#check yob summary
summary(tg_wkr$yob)
# check for duplictes using kp unique identifier
tg_wkr_duplicates<-tg_wkr[duplicated(tg_wkr$kp_unique_identifier),]
# Check for missing values
tg_wkr_missing<-miss_var_cumsum(data = tg_wkr)
#consolidate wkr with ler
# check columns that are not matching
# tg_ler_cols<-setdiff(colnames(tg_ler),colnames(tg_wkr))
# print(tg_ler_cols)
names(tg_wkr)<-names(consolidated_tg)
consolidated_tg<-rbind(tg_wkr,consolidated_tg)

#5LER
tg_ler<-read_excel("LER/KP/TG/TG COnsolidated _March2024.xlsx",sheet = "Sheet1",skip = 7) 
# column_names <- colnames(tg_ler)
# print(column_names)
# converting the columns to be separated by underslere
colnames(tg_ler) <- gsub(" ", "_", colnames(tg_ler))
colnames(tg_ler) <- gsub("-", "_", colnames(tg_ler))
#delete duplicates with no entries
tg_ler<-subset(tg_ler,KP_Type!="")
#removing unwanyed characters
colnames(tg_ler) <- gsub("[<(.)/>]", "", colnames(tg_ler))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(tg_ler)<-tolower(names(tg_ler))
tg_ler <- tg_ler %>%
  rename(kp_unique_identifier = "kp_unique_identifier\r\nsrclient_initialstypologyhotspotpe_codeclient_no")
#check if age is greater than 100
summary(tg_ler$age)
#check yob summary
summary(tg_ler$yob)
# check for duplictes using kp unique identifier
tg_ler_duplicates<-tg_ler[duplicated(tg_ler$kp_unique_identifier),]
# Check for missing values
tg_ler_missing<-miss_var_cumsum(data = tg_ler)
#consolidate ler with ler
# check columns that are not matching
# tg_ler_cols<-setdiff(colnames(tg_ler),colnames(tg_ler))
# print(tg_ler_cols)
names(tg_ler)<-names(consolidated_tg)
consolidated_tg<-rbind(tg_ler,consolidated_tg)






#save conslidated TG
saveRDS(consolidated_tg,file = paste0(path,"consolidated_TG_",today,".RDS"))
write.csv(consolidated_tg,file = paste0(path,"consolidated_TG_",today,".csv"))



#read msm dataset
consolidated_msm<-readRDS("cleandata/msm_consolidated_24-04-12.RDS")
consolidated_msm<-consolidated_msm %>% mutate(
            received_peer_education = ifelse(received_peer_education22=="Yes"| received_peer_education75=="Yes"| received_peer_education128=="Yes", "Yes","No"),
            rssh = ifelse(provided_with_risk_reduction_couselling68=="Yes"| provided_with_risk_reduction_couselling121=="Yes"| provided_with_risk_reduction_couselling174=="Yes", "Yes","No"),
            screened_sti = ifelse(screened_for_stis61=="Yes"| screened_for_stis114=="Yes"| screened_for_stis167=="Yes", "Yes","No"),
            condom_distributed = ifelse(condoms_distributed_nmbr46 > 0| condoms_distributed_nmbr99 > 0| condoms_distributed_nmbr152 > 0, 
                                        as.numeric(condoms_distributed_nmbr46)  + as.numeric(condoms_distributed_nmbr99)  + as.numeric(condoms_distributed_nmbr152) ,0),
)
write.xlsx(consolidated_msm,paste0(path,"consolidated_msm_",today,".xlsx"))
#msm defined package
print(nrow(filter(consolidated_msm,screened_sti=="Yes" & (received_peer_education=="Yes" | rssh=="Yes") & condom_distributed > 0)))

msm_hivtest_counts <- consolidated_msm %>%
  summarise(across(starts_with("tested_for_hiv"), ~ sum(. == "Yes", na.rm = TRUE)))

print(msm_hivtest_counts)

#read fsw dataset
consolidated_fsw<-readRDS("cleandata/Consolidated_fsw_24-04-12RDS")
consolidated_fsw<-consolidated_fsw %>% mutate(
  received_peer_education = ifelse(received_peer_education22=="Yes"| received_peer_education75=="Yes"| received_peer_education128=="Yes", "Yes","No"),
  rssh = ifelse(provided_with_risk_reduction_couselling68=="Yes"| provided_with_risk_reduction_couselling121=="Yes"| provided_with_risk_reduction_couselling174=="Yes", "Yes","No"),
  screened_sti = ifelse(screened_for_stis61=="Yes"| screened_for_stis114=="Yes"| screened_for_stis167=="Yes", "Yes","No"),
  condom_distributed = ifelse(condoms_distributed_nmbr46 > 0| condoms_distributed_nmbr99 > 0| condoms_distributed_nmbr152 > 0, 
                              as.numeric(condoms_distributed_nmbr46)  + as.numeric(condoms_distributed_nmbr99)  + as.numeric(condoms_distributed_nmbr152) ,0),
)
print(nrow(filter(consolidated_fsw,screened_sti=="Yes" & (received_peer_education=="Yes" | rssh=="Yes") & condom_distributed > 0)))



#READ AYP DATA
ayp_consolidated<-read_excel("cleandata/AYP INTEGRATED TRACKER COnsolidated.xlsx",sheet = "Data Sheet")
colnames(ayp_consolidated) <- gsub("[<(.)/>]", "", colnames(ayp_consolidated))
names(ayp_consolidated)<-tolower(names(ayp_consolidated))
ayp_missing<-miss_var_cumsum(data = ayp_consolidated)
ayp_duplicates<-ayp_consolidated[duplicated(ayp_consolidated$`name of peerayp`),]
write.xlsx(ayp_duplicates,paste0(path,"ayp_duplicates",today,".xlsx"))

#mat data
mat_ler<-read_excel("LER/KP/PWID/MAT TRACKER MARCH 2024.xlsx",sheet = "MAT Tracker",skip = 7) 
mat_ler_missing<-miss_var_cumsum(data = mat_ler)
mat_cor<-read_excel("COR/PWID/PWID/COR_Consolidated MAT_RETENTION_ADHERENCE TRACKER-Jan-Mar 2023.xlsx",sheet = "MAT Tracker",skip = 7) 
mat_cor_missing<-miss_var_cumsum(data = mat_cor)



#READ TCS DATA
tcs_data<-read_excel('TCS/COMBINED TCS MARCH 2024.xlsx',sheet = "Sheet1",skip = 1)
tcs_data<-subset(tcs_data,SR !="")
tcs_data_missing<-miss_var_cumsum(data = tcs_data)

#Change gender
# Assuming 'your_data_frame' is your data frame
complete_msm_cohort_registerv1$sex <- ifelse(complete_msm_cohort_registerv1$sex == "Male", "MALE", complete_msm_cohort_registerv1$sex)
complete_msm_cohort_registerv1$peer_educator <- ifelse(complete_msm_cohort_registerv1$peer_educator == "George Oduor", "GEORGE ODUOR", complete_msm_cohort_registerv1$sex)


#count all the peer education received 
peer_education_counts <- consolidated_msm_v1 %>%
  summarise(across(starts_with("received_peer_education"), ~ sum(. == "Yes", na.rm = TRUE)))

print(peer_education_counts)

#count all the risk education services 
risk_services_counts <- complete_msm_cohort_registerv1 %>%
  summarise(across(starts_with("provided_with_risk_reduction_couselling"), ~ sum(. == "Yes", na.rm = TRUE)))

print(risk_services_counts)
#comnination of risk services condo
combined_counts <- consolidated_msm_v1 %>%
  summarise(
    peer_education = across(
      starts_with("screened_for_stis") | 
        starts_with("received_peer_education") | 
        starts_with("provided_with_risk_reduction_couselling"), 
      ~ sum(. == "Yes", na.rm = TRUE)
    ),
    condoms_distributed = across(
      starts_with("condoms_distributed_nmbr"), 
      ~ sum(. > 0, na.rm = TRUE)
    )
  )

print(combined_counts)

#receeived clinical services
#count all the risk education services 
clinical_services_counts <- complete_msm_cohort_registerv1 %>%
  summarise(across(starts_with("received_clinical_services"), ~ sum(. == "Yes", na.rm = TRUE)))

print(clinical_services_counts)
# count all those who received condoms
received_condom_counts <- complete_msm_cohort_registerv1 %>%
  summarise(across(starts_with("condoms_distributed_nmbr"), ~ sum(. > 0, na.rm = TRUE)))

print(received_condom_counts)

#count those who received NSP
msm_cohort_register_nsp_counts <- complete_msm_cohort_registerv1 %>%
  summarise(across(starts_with("received_needles_and_syringes_per_need"), ~ sum(. == "No", na.rm = TRUE)))

print(msm_cohort_register_nsp_counts)

#count those who were screened for STI
msm_cohort_register_sti_counts <- complete_msm_cohort_registerv1 %>%
  summarise(across(starts_with("screened_for_stis"), ~ sum(. == "Yes", na.rm = TRUE)))

print(msm_cohort_register_sti_counts)
#count those who were screened for TB
msm_cohort_register_tb_counts <- complete_msm_cohort_registerv1 %>%
  summarise(across(starts_with("screened_for_tb"), ~ sum(. == "Yes", na.rm = TRUE)))

print(msm_cohort_register_tb_counts)
#count those who were tested for hiv
hivtest_counts_msm <- complete_msm_cohort_registerv1 %>%
  summarise(across(starts_with("tested_for_hiv"), ~ sum(. == "Yes", na.rm = TRUE)))

print(hivtest_counts_msm)

#hiv_status
hiv_status_counts_msm <- complete_msm_cohort_registerv1 %>%
  summarise(across(starts_with("hiv_status"), ~ sum(. == "known positive", na.rm = TRUE)))

print(hiv_status_counts_msm)
#count those who were initiated on prep
prep_intiated_counts_msm <- complete_msm_cohort_registerv2 %>%
  summarise(across(starts_with("initiated_on_prep"), ~ sum(. == "Yes", na.rm = TRUE)))

print(prep_intiated_counts_msm)

#those who received a combnation of STI Screening,(health education or risk counceling) and condoms
sti_he_condoms <- complete_msm_cohort_registerv2 %>%
  mutate(
    either_condition_count = rowSums(
      select(., starts_with("screened_for_stis")) == "Yes" &
        select(., starts_with("received_peer_education")) == "Yes" |
        select(., starts_with("provided_with_risk_reduction_couselling")) == "Yes" &
        select(., starts_with("condoms_distributed_nmbr")) > 0, na.rm = TRUE
    )
  ) %>%
  select(either_condition_count)

total_sti_he_counts <- sti_he_condoms %>%
  filter(either_condition_count >=1)
# Count the number of rows in the filtered result
count_filtered_result <- nrow(total_sti_he_counts)

# Print the count
print(count_filtered_result)

#
sti_he_condoms <- consolidated_msm_v1 %>%
  mutate(
    screened_for_sti_count = rowSums(select(., starts_with("screened_for_stis")) == "Yes", na.rm = TRUE),
    peer_education_count = rowSums(select(., starts_with("received_peer_education")) == "Yes", na.rm = TRUE),
    risk_reduction_counseling_count = rowSums(select(., starts_with("provided_with_risk_reduction_couselling")) == "Yes", na.rm = TRUE),
    condoms_distributed_count = rowSums(select(., starts_with("condoms_distributed_nmbr")) > 0, na.rm = TRUE),
    either_condition_count = rowSums(
      select(., starts_with("screened_for_stis")) == "Yes" &
        select(., starts_with("received_peer_education")) == "Yes" |
        select(., starts_with("provided_with_risk_reduction_couselling")) == "Yes" &
        select(., starts_with("condoms_distributed_nmbr")) > 0, na.rm = TRUE
    )
  ) %>%
  select(screened_for_sti_count,peer_education_count, risk_reduction_counseling_count, condoms_distributed_count, either_condition_count)

#summarize total count




#write in to csv and excel
write.csv(msm_cohort_register,file = paste0(path,"msm_cohort_register_",today,".csv"))
saveRDS(msm_cohort_register,file = paste0(path,"msm_cohort_register_",today,".RDS"))
write_xlsx(msm_cohort_register,paste0("cleandata/msm_cohort_register_",today,".xlsx"))
write_xlsx(msm_cohort_register,"cleandata/msm_cohort_register.xlsx")

#read com;ete data
complete_msm_cohort_registerv3<-readRDS("complete_msm_cohort_registervl_24-01-31.RDS")

#load coastregion
complete_msm_cohort_registerv4 <- complete_msm_cohort_registerv2 %>%
  mutate(
    county = ifelse(substr(kp_unique_identifier, 1, 2) == "05", "LAMU", county)
  )


#2. upper eastern region
TG_consolidated<-read_excel("CONSOLIDATED_TG.xlsx", skip = 7, sheet = "Sheet1")
colnames(TG_consolidated) <- gsub(" ", "_", colnames(TG_consolidated))
colnames(TG_consolidated) <- gsub("-", "_", colnames(TG_consolidated))
#delete duplicates with no entries
TG_consolidated<-subset(TG_consolidated,KP_Type!="")
#removing unwanyed characters
colnames(TG_consolidated) <- gsub("[<(.)/>\\\\]", "", colnames(TG_consolidated))
colnames(TG_consolidated) <- gsub("[\"\\\\]", "", colnames(TG_consolidated))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(TG_consolidated)<-tolower(names(TG_consolidated))
# msm dataset


#consolidated MSM
msm_dataset<-read_excel("CONSOLIDATED-MSM_JULY-DEC 1.xlsx",sheet = "Sheet1",skip = 7) 
#checking dates
#checking dupicates for both peer name and kp unique identifier
# converting the columns to be separated by underscore
colnames(msm_dataset) <- gsub(" ", "_", colnames(msm_dataset))
colnames(msm_dataset) <- gsub("-", "_", colnames(msm_dataset))
#delete duplicates with no entries
msm_dataset<-subset(msm_dataset,KP_Type!="")
#removing unwanyed characters
colnames(msm_dataset) <- gsub("[<(.)/>]", "", colnames(msm_dataset))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(msm_dataset)<-tolower(names(msm_dataset))
msm_dataset <- msm_dataset %>%
  rename(kp_unique_identifier = "kp_unique_identifier\r\nsrclient_initialstypologyhotspotpe_codeclient_no")
msm_dataset <- msm_dataset %>%
  rename(date_of_next_appointment = "date_of_next_appointment\r\ndd_mm_yyyy_eg_02_may_2018126")
msm_dataset <- msm_dataset %>%
  rename(kp_name = "kp's_name3_names_&_nickname")
msm_dataset <- msm_dataset %>%
  rename(date_of_first_contact = "date_of_first_contact_ddmmyyyy")
msm_dataset <- msm_dataset %>%
  rename(date_of_enrollment = "date_of_enrolment_ddmmyyyy")
#keep columns of interest
# Define prefixes
prefixes <- c("county", "region", "sr_name", "age", "sex", "peer_educator","hiv_status_at_enrollment","received_peer_education", 
              "tested_for_hiv", "screened_for_stis", "condoms_distributed_nmbr", "screened_for_tb", 
              "provided_with_risk_reduction_couselling", "initiated_on_prep")

# Subset columns that start with any of the specified prefixes
msm_consolidated_subset <- msm_dataset[, grepl(paste0("^", paste(prefixes, collapse = "|")), names(msm_dataset))]
# save dataset
saveRDS(msm_dataset,file="msm_consolidated.RDS")
saveRDS(msm_consolidated_subset,file = "D:/PROJECTS/KRCS/msm_consolidated.RDS")
saveRDS(msm_consolidated_subset,"C:/Users/Admin/OneDrive - Kenya Red Cross Society/PROJECTS/KRCS-ANALYTICS/msm_consolidated.RDS")

#histogram for age
hist(consolidated_msm_v1$age, col = "skyblue", main = "Histogram of Ages", xlab = "Age")
#scatter plot
# Assuming your data frame is named 'your_data_frame'
plot(consolidated_msm_v1$age, consolidated_msm_v1$region, 
     col = "blue", pch = 16, 
     main = "Scatter Plot", 
     xlab = "Age", ylab = "Region")


#TG DATA consolidated
tg_consolidated<-read_excel("TG-CONSOLIDATED_updated.xlsx", skip = 7, sheet = "Sheet1")
colnames(tg_consolidated) <- gsub(" ", "_", colnames(tg_consolidated))
colnames(tg_consolidated) <- gsub("-", "_", colnames(tg_consolidated))
#delete duplicates with no entries
tg_consolidated<-subset(tg_consolidated,KP_Type!="")
#removing unwanyed characters
colnames(tg_consolidated) <- gsub("[<(.)/>\\\\]", "", colnames(tg_consolidated))
colnames(tg_consolidated) <- gsub("[\"\\\\]", "", colnames(tg_consolidated))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(tg_consolidated)<-tolower(names(tg_consolidated))
tg_consolidated <- tg_consolidated %>%
  rename(kp_unique_identifier = "kp_unique_identifier\r\nsrclient_initialstypologyhotspotpe_codeclient_no")
tg_consolidated <- tg_consolidated %>%
  rename(date_of_next_appointment = "date_of_next_appointment\r\ndd_mm_yyyy_eg_02_may_2018126")

#checking for duplicates
tg_consolidated$kp_uniq<-paste0(tg_consolidated$`kp's_name3_names_&_nickname`,tg_consolidated$kp_unique_identifier)
tg_consolidated[duplicated(tg_consolidated$kp_uniq)=="kp_uniq",]
tg_consolidated<-select(tg_consolidated,-kp_uniq)
#renaming North Rift Region to NRR
tg_consolidated$region <- ifelse(tg_consolidated$region == "North Rift Region", "NRR", tg_consolidated$region)

#clean HIV status at enrollment
tg_consolidated$hiv_status_at_enrollment<-ifelse(tg_consolidated$hiv_status_at_enrollment == "positive", "Positive", tg_consolidated$hiv_status_at_enrollment)
tg_consolidated$hiv_status_at_enrollment<-ifelse(tg_consolidated$hiv_status_at_enrollment == "negative", "Negative", tg_consolidated$hiv_status_at_enrollment)
tg_consolidated$hiv_status_at_enrollment<-ifelse(tg_consolidated$hiv_status_at_enrollment == "Unknown", "Unknown ", tg_consolidated$hiv_status_at_enrollment)
tg_consolidated$hiv_status_at_enrollment<-ifelse(tg_consolidated$hiv_status_at_enrollment == "Uknown", "Unknown ", tg_consolidated$hiv_status_at_enrollment)
tg_consolidated$hiv_status_at_enrollment<-ifelse(tg_consolidated$hiv_status_at_enrollment == "Known positive", "Known Positive", tg_consolidated$hiv_status_at_enrollment)
tg_consolidated$hiv_status_at_enrollment<-ifelse(tg_consolidated$hiv_status_at_enrollment == "known Positive", "Known Positive", tg_consolidated$hiv_status_at_enrollment)
tg_consolidated$hiv_status_at_enrollment<-ifelse(tg_consolidated$hiv_status_at_enrollment == "unknown", "Unknown", tg_consolidated$hiv_status_at_enrollment)
tg_consolidated$hiv_status_at_enrollment<-ifelse(tg_consolidated$hiv_status_at_enrollment == "Known Positive", "Known Positve", tg_consolidated$hiv_status_at_enrollment)

#keeing necessary columns
prefixes <- c("county", "region", "sr_name", "age", "sex", "peer_educator","hiv_status_at_enrollment","received_peer_education", 
              "tested_for_hiv", "screened_for_stis", "condoms_distributed_nmbr", "screened_for_tb", 
              "provided_with_risk_reduction_couselling", "initiated_on_prep")

# Subset columns that start with any of the specified prefixes
tg_consolidated_subset <- tg_consolidated[, grepl(paste0("^", paste(prefixes, collapse = "|")), names(tg_consolidated))]

#exporting data to csv file under the projects
saveRDS(tg_consolidated_subset,file="C:/Users/Admin/OneDrive - Kenya Red Cross Society/PROJECTS/KRCS-ANALYTICS/tg_consolidatd.RDS")

#PWID
pwid_consolidated<-read_excel("Final Consolidated PWID Data July-Dec 2023_05022024 1.xlsx",sheet = "Sheet1 (2)",skip = 7)
colnames(pwid_consolidated) <- gsub(" ", "_", colnames(pwid_consolidated))
colnames(pwid_consolidated) <- gsub("-", "_", colnames(pwid_consolidated))
#delete duplicates with no entries
pwid_consolidated<-subset(pwid_consolidated,KP_Type!="")
#removing unwanyed characters
colnames(pwid_consolidated) <- gsub("[<(.)/>\\\\]", "", colnames(pwid_consolidated))
colnames(pwid_consolidated) <- gsub("[\"\\\\]", "", colnames(pwid_consolidated))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(pwid_consolidated)<-tolower(names(pwid_consolidated))
pwid_consolidated <- pwid_consolidated %>%
  rename(kp_unique_identifier = "kp_unique_identifier\r\nsrclient_initialstypologyhotspotpe_codeclient_no")
pwid_consolidated <- pwid_consolidated %>%
  rename(date_of_next_appointment = "date_of_next_appointment\r\ndd_mm_yyyy_eg_02_may_2018126")
#few summary statistics
#check eage anomalies
describe(pwid_consolidated$age)
#check yob
summary(pwid_consolidated$yob)

#check for duplicates
pwid_consolidated$kp_uniq<-paste0(pwid_consolidated$`kp's_name3_names_&_nickname`,pwid_consolidated$kp_unique_identifier)
pwid_consolidated[duplicated(pwid_consolidated$kp_uniq)=="kp_uniq",]
pwid_consolidated<-select(pwid_consolidated,-kp_uniq)
#change date of enrollment to dates
#clean HIV status at enrollment
pwid_consolidated$hiv_status_at_enrollment<-ifelse(pwid_consolidated$hiv_status_at_enrollment == "positive", "Positive", pwid_consolidated$hiv_status_at_enrollment)
pwid_consolidated$hiv_status_at_enrollment<-ifelse(pwid_consolidated$hiv_status_at_enrollment == "negative", "Negative", pwid_consolidated$hiv_status_at_enrollment)
pwid_consolidated$hiv_status_at_enrollment<-ifelse(pwid_consolidated$hiv_status_at_enrollment == "Unknown", "Unknown ", pwid_consolidated$hiv_status_at_enrollment)
pwid_consolidated$hiv_status_at_enrollment<-ifelse(pwid_consolidated$hiv_status_at_enrollment == "Uknown", "Unknown ", pwid_consolidated$hiv_status_at_enrollment)
pwid_consolidated$hiv_status_at_enrollment<-ifelse(pwid_consolidated$hiv_status_at_enrollment == "Known positive", "Known Positive", pwid_consolidated$hiv_status_at_enrollment)
pwid_consolidated$hiv_status_at_enrollment<-ifelse(pwid_consolidated$hiv_status_at_enrollment == "known Positive", "Known Positive", pwid_consolidated$hiv_status_at_enrollment)
pwid_consolidated$hiv_status_at_enrollment<-ifelse(pwid_consolidated$hiv_status_at_enrollment == "unknown", "Unknown", pwid_consolidated$hiv_status_at_enrollment)
pwid_consolidated$hiv_status_at_enrollment<-ifelse(pwid_consolidated$hiv_status_at_enrollment == "Known Positive", "Known Positve", pwid_consolidated$hiv_status_at_enrollment)

#KEEP COLUMNS OF INTERST
#keeing necessary columns
prefixes <- c("county", "region", "sr_name", "age", "sex", "peer_educator","hiv_status_at_enrollment","received_peer_education", 
              "tested_for_hiv", "screened_for_stis", "condoms_distributed_nmbr", "screened_for_tb", 
              "provided_with_risk_reduction_couselling", "initiated_on_prep","needles_and_syringes_distributed_nmbr")

# Subset columns that start with any of the specified prefixes
pwid_consolidated_subset <- pwid_consolidated[, grepl(paste0("^", paste(prefixes, collapse = "|")), names(pwid_consolidated))]

#saving data
saveRDS(pwid_consolidated,file="PWID_Consolidated.RDS")
saveRDS(pwid_consolidated_subset,file="C:/Users/Admin/OneDrive - Kenya Red Cross Society/PROJECTS/KRCS-ANALYTICS/PWID_consolidated.RDS")

#FSM dataset
fsm_consolidated<-read_excel("FSW Cohort register consolodated update.xlsx", skip = 2, sheet = "Sheet1")
# converting the columns to be separated by underscore
colnames(fsm_consolidated) <- gsub(" ", "_", colnames(fsm_consolidated))
colnames(fsm_consolidated) <- gsub("-", "_", colnames(fsm_consolidated))
#delete duplicates with no entries
fsm_consolidated<-subset(fsm_consolidated,KP_Type!="")
#removing unwanyed characters
colnames(fsm_consolidated) <- gsub("[<(.)/>]", "", colnames(fsm_consolidated))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(fsm_consolidated)<-tolower(names(fsm_consolidated))
fsm_consolidated <- fsm_consolidated %>%
  rename(kp_unique_identifier = "kp_unique_identifier\r\nsrclient_initialstypologyhotspotpe_codeclient_no")
fsm_consolidated <- fsm_consolidated %>%
  rename(date_of_next_appointment = "date_of_next_appointment\r\ndd_mm_yyyy_eg_02_may_2018126")
fsm_consolidated <- fsm_consolidated %>%
  rename(kp_name = "kp's_name3_names_&_nickname")
fsm_consolidated <- fsm_consolidated %>%
  rename(date_of_first_contact = "date_of_first_contact_ddmmyyyy")
fsm_consolidated <- fsm_consolidated %>%
  rename(date_of_enrollment = "date_of_enrolment_ddmmyyyy")

#check if date of contact is greater than date of enrollment
date_error<-subset(fsm_consolidated,date_of_first_contact>date_of_enrollment)
#change date errors
# fsm_consolidated[fsm_consolidated$sno == 4600, "date_of_enrollment"] <- as.Date("2023-10-09")
# fsm_consolidated[fsm_consolidated$sno == 87450, "date_of_enrollment"] <- as.Date("2020-09-07")
#check for missing variables
missing_date_enrollment<-miss_var_summary(fsm_consolidated)
#check for date anomalies to know range of date.
summary(fsm_consolidated$age)

#keeing necessary columns
prefixes <- c("county", "region", "sr_name", "age", "sex", "peer_educator","hiv_status_at_enrollment","received_peer_education", 
              "tested_for_hiv", "screened_for_stis", "condoms_distributed_nmbr", "screened_for_tb", 
              "provided_with_risk_reduction_couselling", "initiated_on_prep")

# Subset columns that start with any of the specified prefixes
fsw_consolidated_subset <- fsm_consolidated[, grepl(paste0("^", paste(prefixes, collapse = "|")), names(fsm_consolidated))]

#save consolidated date
saveRDS(fsm_consolidated,file="E:/PROJECTS/KRCS/fsw_consolidated.RDS")
saveRDS(fsw_consolidated_subset,file="C:/Users/Admin/OneDrive - Kenya Red Cross Society/PROJECTS/KRCS-ANALYTICS/fsw_consolidated.RDS")


#readEBI dataset
#HCBF
ebi_consolidated<-read_excel("Consolidated EBI Tracker.xlsx",sheet = "HCBF",skip = 1)
colnames(ebi_consolidated) <- gsub(" ", "_", colnames(ebi_consolidated))
colnames(ebi_consolidated) <- gsub("-", "_", colnames(ebi_consolidated))
colnames(ebi_consolidated) <- gsub(":", "", colnames(ebi_consolidated))
colnames(ebi_consolidated) <- gsub("?", "", colnames(ebi_consolidated))
#delete duplicates with no entries
#removing unwanyed characters
colnames(ebi_consolidated) <- gsub("[<(.)/>\\\\]", "", colnames(ebi_consolidated))
colnames(ebi_consolidated) <- gsub("[\"\\\\]", "", colnames(ebi_consolidated))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(ebi_consolidated)<-tolower(names(ebi_consolidated))
#rename
ebi_consolidated <- ebi_consolidated %>%
  rename(complete_sessions = "complete_sessions?")

#select columns of interest for dashboard
ebi_consolidated<-select(ebi_consolidated,region,start_date,end_date,age,sex,complete_sessions)

#save file to the dashboard as RDS
saveRDS(ebi_consolidated,file = "E:/PROJECTS/KRCS/ebi_consolidated_HBCF.RDS")
saveRDS(ebi_consolidated,file="C:/Users/Admin/OneDrive - Kenya Red Cross Society/PROJECTS/KRCS-ANALYTICS/ebi_consolidated_HBCF.RDS")


#readEBI dataset
#HCBF
ebi_consolidated_MHMC<-read_excel("Consolidated EBI Tracker.xlsx",sheet = "MHMC",skip = 1)
colnames(ebi_consolidated_MHMC) <- gsub(" ", "_", colnames(ebi_consolidated_MHMC))
colnames(ebi_consolidated_MHMC) <- gsub("-", "_", colnames(ebi_consolidated_MHMC))
colnames(ebi_consolidated_MHMC) <- gsub(":", "", colnames(ebi_consolidated_MHMC))
colnames(ebi_consolidated_MHMC) <- gsub("?", "", colnames(ebi_consolidated_MHMC))
#delete duplicates with no entries
#removing unwanyed characters
colnames(ebi_consolidated_MHMC) <- gsub("[<(.)/>\\\\]", "", colnames(ebi_consolidated_MHMC))
colnames(ebi_consolidated_MHMC) <- gsub("[\"\\\\]", "", colnames(ebi_consolidated_MHMC))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(ebi_consolidated_MHMC)<-tolower(names(ebi_consolidated_MHMC))
#rename
ebi_consolidated_MHMC <- ebi_consolidated_MHMC %>%
  rename(complete_sessions = "complete_sessions?")
#select columns of interest for dashboard
ebi_consolidated_MHMC<-select(ebi_consolidated_MHMC,region,start_date,end_date,age,sex,complete_sessions)
saveRDS(ebi_consolidated_MHMC,file="C:/Users/Admin/OneDrive - Kenya Red Cross Society/PROJECTS/KRCS-ANALYTICS/ebi_consolidated_MHMC.RDS")

#save file to the dashboard as RDS
saveRDS(ebi_consolidated,file = "E:/PROJECTS/KRCS/ebi_consolidated_MHMC.RDS")

#mentorship tracker
menttorship_tracker<-read_excel("Consolidated Mentorship Tracker.xlsx",skip = 1,sheet = "Data_Sheet")
colnames(menttorship_tracker) <- gsub(" ", "_", colnames(menttorship_tracker))
colnames(menttorship_tracker) <- gsub("-", "_", colnames(menttorship_tracker))
colnames(menttorship_tracker) <- gsub(":", "", colnames(menttorship_tracker))
colnames(menttorship_tracker) <- gsub("?", "", colnames(menttorship_tracker))
colnames(menttorship_tracker) <- gsub("[<(.)/>\\\\]", "", colnames(menttorship_tracker))
colnames(menttorship_tracker) <- gsub("[\"\\\\]", "", colnames(menttorship_tracker))
# colnames(cohort_register) <- abbreviate(colnames(cohort_register), minlength = 16)
names(menttorship_tracker)<-tolower(names(menttorship_tracker))
menttorship_tracker <- menttorship_tracker %>%
  rename(complete_sessions = "completed_all_sessions_status_completenot_complete")
#select columns of interest for dashboard
menttorship_tracker<-select(menttorship_tracker,region,start_date,end_date,age,sex,complete_sessions)

saveRDS(menttorship_tracker,file = "D:/PROJECTS/KRCS/mentorshipConsolidated.RDS")
saveRDS(menttorship_tracker,file="C:/Users/Admin/OneDrive - Kenya Red Cross Society/PROJECTS/KRCS-ANALYTICS/menttorship_tracker.RDS")

received_niddle_syring_msm <- pwid_consolidated %>%
  summarise(across(starts_with("needles_and_syringes_distributed_nmbr"), ~ sum(. > 0, na.rm = TRUE)))
received_niddle_syring_msm <- received_niddle_syring_msm %>%
  select(where(~ . > 0))

#remove all objects fromworkspace
rm(list = ls())
