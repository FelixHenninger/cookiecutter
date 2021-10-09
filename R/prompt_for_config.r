prompt_for_config <- function(options) {
  # TODO: Can we map directly to a list? (instead of using stupid tricks)
  output <- list()

  purrr::map2(names(options), options, function(k, v) {
    if (length(v) > 1) {
      # Selection from a set of values
      rlang::inform('Please select an option for ', k)
      output[k] <<- utils::menu(v)
    } else {
      # Free input
      rlang::inform(paste0('Please enter a value for ', k, ' [', v, ']'))
      choice <- base::readline()

      # Insert default if no value was provided
      if (choice == '') {
        output[k] <<- v
      } else {
        output[k] <<- choice
      }
    }
    # TODO: Support nested lists / dictionaries
  })

  return(output)
}
