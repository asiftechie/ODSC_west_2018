#' Author: Ted Kwartler
#' Date: 6-18-2018
#' Purpose: Lending Club Modeling, Cross Validation, Variable Treatment, Save Algo
#'

# WD
setwd("C:/Users/Edward/Desktop/odsc blogs/presentation/ODSC_west_2018/workshop_data/LC")


# Libraries
library(rpart)
library(randomForest)
library(dplyr)
library(caret)
library(e1071)
library(vtreat)

# I/O
df <- read.csv('20K_sampleLoans.csv') 
head(df[,c(1:5,10:11)])

# Keep the pertinent information; as you explore you can add others or delete
keeps <-c("loan_amnt", "term", "int_rate", "installment", "grade", "sub_grade", "emp_length" , "home_ownership", "annual_inc", "purpose", "title", "zip_code", "addr_state", "dti", "delinq_2yrs", "pub_rec_bankruptcies", "inq_last_6mths", "mths_since_last_delinq", "mths_since_last_record", "open_acc", "pub_rec", "revol_bal", "revol_util", "total_acc", "initial_list_status", "collections_12_mths_ex_med", "mths_since_last_major_derog","y")

df <- df[,keeps]

# Partitioning 
set.seed(1234)
num <- (nrow(df) %/% 10) * 8
idx <- sample(1:nrow(df), num)

# Training Subset 
trainDF      <- df[idx,]

## Data Prep
#Make % a numeric
trainDF$revol_util <- gsub('%', '', trainDF$revol_util) %>%
                  as.character() %>% 
                  as.numeric()


trainDF$int_rate   <- gsub('%', '', trainDF$int_rate)   %>%
                  as.character() %>% 
                  as.numeric()

# Now easy variable treatment plan
dataPlan <-designTreatmentsC(dframe        = trainDF, 
                             varlist       = keeps,
                             outcomename   = 'y', 
                             outcometarget = 1)

# Now apply the plan to the data
treatedDF <- prepare(dataPlan, trainDF)

ncol(df)
ncol(treatedDF)

names(df)
names(treatedDF)

# Now let's do a logistic regression with a 10 fold CV
crtl <- trainControl(method = "cv", 
                     number = 3, # Better to do 10
                     verboseIter = TRUE)

# Fit lm model using 3-fold CV: model
fit3 <- train(as.factor(y) ~ ., 
              data = treatedDF,
              method="glm", family="binomial",
              trControl = crtl)
fit3
preds <- predict(fit3)
table(preds, trainDF$y)

# Save the model
# In R GLM model objects are huge, saving a lot of extra info.  This gets rid of a lot of it but retains the ability to make predictions.
trimTrain <- function(object, ...) {
  removals <- c("results", "pred", "bestTune", "call", "dots",
                "metric", "trainingData", "resample", "resampledCM",
                "perfNames", "maxmimize", "times")
  for(i in removals)
    if(i %in% names(object)) object[i] <- NULL
    c_removals <- c('method', 'number', 'repeats', 'p', 'initialWindow', 
                    'horizon', 'fixedWindow', 'verboseIter', 'returnData', 
                    'returnResamp', 'savePredictions', 'summaryFunction', 
                    'selectionFunction', 'index', 'indexOut', 'indexFinal',
                    'timingSamps', 'trim', 'yLimits')
    for(i in c_removals)
      if(i %in% names(object$control)) object$control[i] <- NULL  
    if(!is.null(object$modelInfo$trim))
      object$finalModel <- object$modelInfo$trim(object$finalModel)
    object
}

# Before size
object.size(fit3)/1000

# Trim
fit3 <- trimTrain(fit3)

# After trim
object.size(fit3)/1000

# Save a copy of the model
pth<-'LogRegCV_fit3.rds'
saveRDS(fit3, pth)

# Save the treatment plan
pth<-'treatmentPlan_fit3.rds'
saveRDS(dataPlan, pth)

# End