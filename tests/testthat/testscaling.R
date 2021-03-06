mp_emptycache()
mp_setapikey(key.file = "../manifesto_apikey.txt")

mpds <- mp_maindataset()

test_that("rile computation from corpus equals dataset value", {
  
  mpds.blg <- subset(mpds, countryname=="Bulgaria" &
                           edate > as.Date("2000-01-01"))

  corpus_riles <- mp_scale(mp_corpus(mpds.blg), scalingfun = rile)
  joint_riles <- left_join(corpus_riles,
                           select(mpds.blg, one_of("party", "date", "rile")),
                           by = c("party", "date"))
  
  expect_equal(joint_riles$rile.x,
               joint_riles$rile.y,
               tolerance = 0.1)
  
})

test_that("rile computation for pathological data points works", {

  mpds_onevar <- subset(mpds, country == 32 & date == 201302 & party > 32900)

  corpus_riles <- mp_scale(mp_corpus(mpds_onevar), scalingfun = rile)
  joint_riles <- left_join(corpus_riles,
                           select(mpds_onevar, one_of("party", "date", "rile")),
                           by = c("party", "date"))

  expect_equal(joint_riles$rile.x,
               joint_riles$rile.y,
               tolerance = 0.1)

})

test_that("weighted scaling works for different formats of weights", {
  
  testdata <- data.frame(per101 = c(0.5, 0.0, 1.0),
                         per404 = c(0.0, 1.0, 0.0),
                         per666 = c(0.5, 0.0, 0.0),
                         pervote = c(0.3, 0.7, 0.2))
  
  ## if weights is a scalar
  expect_equal(scale_weighted(testdata,
                        weights = 1),
               c(1, 1, 1))
  
  ## if weights is an unnamed vector
  expect_equal(scale_weighted(testdata,
                        weights = c(1, -1, 0)),
               c(0.5, -1.0, 1.0))
  
  ## if weights is a named list
  expect_equal(scale_weighted(testdata,
                        weights = list(per404 = 0.5, per666 = -0.5, per101 = 0.0)),
               c(-0.25, 0.5, 0.0))
  
  ## if weights is an unnamed list
  expect_equal(scale_weighted(testdata,
                        weights = list(0.5, -0.5, 0.0)),
               c(0.25, -0.5, 0.5))
  
  ## if weights is a matrix of correct dimensions
  expect_equal(scale_weighted(testdata,
                        weights = matrix(c(1, 2, 3,
                                           4, 5, 6,
                                           7, 8, 9),
                                         nrow = 3,
                                         byrow = TRUE)),
               c(2, 5, 7))
  
  ## if weights is a matrix of incorrect dimensions
  expect_error(scale_weighted(testdata,
                        weights = matrix(c(1, 2, 3,
                                           7, 8, 9),
                                         nrow = 2,
                                         byrow = TRUE)))
               
  ## if weights is a data.frame with only pers
  expect_equal(scale_weighted(testdata,
                        weights = data.frame(per404 = c(1, 0.5, 0.0),
                                             per666 = c(1, -0.5, 0.0),
                                             per101 = c(1, 0.0, 0.0))),
               c(1, 0.5, 0))
  
  ## if weights is a data.frame with more variables
  expect_equal(scale_weighted(testdata,
                        weights = data.frame(per404 = c(1, 0.5, 0.0),
                                             project = c("C", "M", "P"),
                                             per666 = c(1, -0.5, 0.0),
                                             per101 = c(1, 0.0, 0.0))),
                        c(1, 0.5, 0))
})

scaling_as_expected <- function(corp, scalingfun, scalingname) {
  
  scale1 <- mp_scale(corp[[1]], scalingfun = scalingfun, scalingname = scalingname)
  expect_is(scale1, "numeric")
  expect_false(is.na(scale1))
  
  scale_corp <- mp_scale(corp, scalingfun = scalingfun, scalingname = scalingname)
  expect_is(scale_corp, "data.frame")
  expect_true(all(c("party", "date", scalingname) %in% names(scale_corp)))
  expect_false(any(is.na(scale_corp[,scalingname])))
  expect_equal(nrow(scale_corp), length(corp))
}

test_that("corpus and document scaling works", {
  
  mpds <- mp_maindataset()
  mpds.fr <- subset(mpds, countryname == "France")
  
  corp <- mp_corpus(mp_metadata(mpds.fr) %>% subset(annotations))

  scaling_as_expected(corp, rile, "rile")
  scaling_as_expected(corp, logit_rile, "logit_rile")
  
  ## expect a "deprecated warning" when old format is used
  expect_warning(rile(corp))

})

test_that("logit_rile scaling works", {

  mpds.fr <- subset(mp_maindataset(), countryname == "France")

  logit_scaled <- logit_rile(mpds.fr)
  expect_is(logit_scaled, "numeric")
  expect_false(any(is.na(logit_scaled)))

  corp <- mp_corpus(mp_metadata(mpds.fr) %>% subset(annotations))
  
  scaling_as_expected(corp, logit_rile, "logit_rile")

})

test_that("Rile on Handbook version 5 data works", {
  
  mpds <- mp_maindataset()
  mpds.cr <- subset(mpds, countryname == "Cyprus")
  
  corp <- mp_corpus(mp_metadata(mpds.cr) %>% subset(annotations))
  
  scaling_as_expected(corp, rile, "rile")
  scaling_as_expected(corp, logit_rile, "logit_rile")
})

test_that("scalingname defaults to deparsed function name", {
  
  mpds.fr <- subset(mp_maindataset(), countryname == "France")

  corp <- mp_corpus(mp_metadata(mpds.fr) %>% subset(annotations))
  
  scale_corp <- mp_scale(corp, scalingfun = rile)
  expect_true(all(c("party", "date", "rile") %in% names(scale_corp)))

  test_fun <- functional::Curry(scale_weighted, weights = list(per108 = 1,
                                                               per110 = -1))
  scale_corp <- mp_scale(corp, scalingfun = test_fun)
  expect_true(all(c("party", "date", "test_fun") %in% names(scale_corp)))

})

test_that("Vanilla scaling produces no error", {
  
  allpers <- filter(mpds, country<70) %>% 
    filter(date > 198000) %>%
    select(dplyr::matches("(^per(\\d{3}|(uncod))$)|(rile)"))
  
  ### vanilla test
  
  allpers$vanilla.inv <- vanilla(allpers, invert=1)
  allpers$vanilla <- vanilla(allpers, invert=0)
  
})

test_that("Franzmann Kaiser scaling produces no error", {
  
  sample <- mpds %>% filter(country==22, date> 198900, date < 200612)
  
  fk <- franzmann_kaiser(sample,basevalues=FALSE,smoothing=FALSE)
  s <- cbind(sample,fk)
  
  
  franzmann_kaiser(sample,basevalues=TRUE,smoothing=FALSE)
  franzmann_kaiser(sample,basevalues=FALSE,smoothing=TRUE)
  franzmann_kaiser(sample,basevalues=TRUE,smoothing=TRUE)
  
})


check_fk_results <- function(test_scores,
                             fk_scores,
                             min_date = as.Date("1982-01-01"),
                             max_date = as.Date("2000-01-01"),
                             tolerance = 0.11) {

  test_scores$manifestoR_fk <- franzmann_kaiser(test_scores, basevalues = TRUE, smoothing = TRUE, use_period_length = FALSE, mean_presplit = TRUE, presplit_countrycode = 21) 
  test_scores <- test_scores %>%
    subset(!is.na(manifestoR_fk)) %>%
    left_join(fk_scores, by = c("party", "edate")) %>%
    select(one_of("party", "edate", "LR_general", "manifestoR_fk")) %>%
    mutate(diff = abs(LR_general - manifestoR_fk))
  
  # qplot(LR_general, manifestoR_fk, data = test_scores) + geom_smooth(method = lm) + facet_grid(. ~ edate)
  
  test_scores %>%
    subset(edate < max_date & edate > min_date & !is.na(diff)) %>%
    summarise(m = max(diff)) %>%
    unlist() %>%
    expect_less_than(tolerance)
  
}


test_that("Franzmann Kaiser scaling works", {
  
  fk_scores <- read.csv("../data/lrfranz.csv", sep = ";") %>%
    mutate(date = as.integer(format(as.Date(edate, format = "%d.%m.%Y"), format = "%Y%m")),
           edate = as.Date(edate, format = "%d.%m.%Y"),
           year = as.integer(substr(date, 1, 4)),
           LR_general = as.numeric(gsub(",", ".", LR_general))) %>%
    rename(country = Country) %>%
    select(-one_of("LR_economic", "LR_social"))
    
  mp_maindataset(version = "MPDS2015a") %>%
    dplyr::filter(country==22, edate > as.Date("1980-01-01")) %>%
    check_fk_results(fk_scores)
  
  mp_maindataset(version = "MPDS2015a") %>%
    dplyr::filter(country==21, edate > as.Date("1960-01-01"), edate < as.Date("1990-01-01")) %>%
    check_fk_results(fk_scores,
                     min_date = as.Date("1971-01-01"),
                     max_date = as.Date("1982-01-01"),
                     tolerance = 1.1)
  
})


