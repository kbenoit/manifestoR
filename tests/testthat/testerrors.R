mp_setapikey("../manifesto_apikey.txt")

test_that("invalid API key hint", {
  
  expect_error(mp_maindataset(apikey = "asdasdasd", cache = FALSE), "401.*invalid API")
  
})

test_that("invalid dataset version hint", {

  expect_error(mp_maindataset("2014-1", cache = FALSE), "404.*does not exist.*check.*parameters")
  
})

test_that("warning when incorrect meta/doc requested", {
  
  expect_warning(mp_metadata(data.frame(party = 123123, date = 123123), cache = FALSE),
                 "No.*found.*check.*request")
  expect_warning(mp_corpus(data.frame(party = 123123, date = 123123), cache = FALSE),
                 "No.*found.*check.*request")
  
})