# Load packages
library(devtools)
source_url('https://raw.githubusercontent.com/FredHasselman/ManyLabRs/master/manylabRs/R/getData.R')
source_url('https://raw.githubusercontent.com/FredHasselman/ManyLabRs/master/manylabRs/R/inIT.R')
# This will load and (if necessary) install libraries frequently used for data management and plotting
in.IT(c('plyr','dplyr','httr','rio','haven'))

# Read the data from OSF storage
#
# Note: get.OSFfile() returns a list with the .csv data (df) and information (info) containing the URL download timestamp and original column and rownames (these names will be changed if dfCln=TRUE).
RPPdata <- get.OSFfile(code='https://osf.io/fgjvw/',dfCln=TRUE)$df

# Figure out how many NAs result from changing to numeric
errs <- llply(1:ncol(RPPdata), function(c) try.CATCH(sum(is.na(as.numeric(RPPdata[c][[1]])))))

nNA  <- laply(seq_along(errs), function(e) if(is.integer(errs[[e]]$value)){errs[[e]]$value}else{168})
# Which variables are numeric
nINT <- colwise(is.numeric)(RPPdata)

# These variables are likely Character format and should be changed to Numeric format
varnames <-  colnames(RPPdata[,(nNA<120)&!nINT])
# [1] "Surprising.result.O"          "Exciting.result.O"            "Replicated.study.number.R"    "N.O"
# [5] "80.power"                     "90.power"                     "95.power"                     "Planned.Power"
# [9] "Original.Author.s.Assessment" "P.value.R"                    "Power.R"


# Fix it!
for(cn in varnames){
    RPPdata[cn] <- as.numeric(RPPdata[cn][[1]])
}

# Convert empty cells to NA
l_ply(1:ncol(RPPdata), function(c) if(is.character(RPPdata[c][[1]])){
    RPPdata[c][[1]] <<- zap_empty(RPPdata[c][[1]])
    }
)

# Use package rio for export to:
#
# Comma seperated
rio::export(RPPdata,"RPPdataConverted.csv")
# Tab delimeted
rio::export(RPPdata,"RPPdataConverted.tsv")
# SPSS
haven::write_sav(RPPdata,"RPPdataConverted.sav")
# Excel
rio::export(RPPdata,"RPPdataConverted.xlsx")
# Stata
rio::export(RPPdata,"RPPdataConverted.dta")
# R (serialized object)
rio::export(RPPdata,"RPPdataConverted.rds")
