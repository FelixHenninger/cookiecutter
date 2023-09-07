#' Generate a new directory from a template, given a predefined context
#'
#' @param template_dir Template directory to copy
#' @param output_dir Target directory to copy to (defaults to project directory)
#' @param context Data available in templates
#' @param context_prefix Prefix key to apply to context data (see description)
#' @param exclude Files to exclude, as an array of paths with respect to
#'  the template directory
#' @param overwrite Whether to overwrite existing files
#'
#' @keywords internal
#'
generate_files <- function(
  template_dir,
  output_dir,
  context=list(),
  context_prefix=NA,
  exclude=c(),
  overwrite=FALSE
) {
  if (missing(template_dir))
    rlang::abort('Please specify a template directory to start from')
  if (missing(output_dir))
    rlang::abort('Please specify an output directory to fill')

  # Iterate through source files
  template_files <- list.files(template_dir, recursive = TRUE)

  # Add context prefix if specified
  if (!is.na(context_prefix)) {
    temp <- list()
    temp[[context_prefix]] <- context
    context <- temp
  }

  for (template_path in template_files) {
    # Skip excluded files
    if (template_path %in% exclude) next

    # Render file path and -name
    template_path_segments <- unlist(fs::path_split(template_path))
    output_path_segments <-
      purrr::map_chr(template_path_segments, function(s) {
        rendered_segment <- whisker::whisker.render(s, context)

        if (rendered_segment != fs::path_sanitize(rendered_segment)) {
          # Fail if the output path contains unsavory information
          rlang::abort(paste(
            'Segment', s, 'of path', template_path,
            'did not pass the sanitization check.',
            'It would have resolved to', fs::path_join(rendered_segment), '.',
            'Please take a look!'
          ))
        } else if (rendered_segment == '') {
          # Fail if parts of the output path are empty
          rlang::abort(paste(
            'Segment', s, 'of path', template_path,
            'resolved to an empty string.',
            'There might be an unspecified template variable.',
            'Please take a look!'
          ))
        }

        return(rendered_segment)
      })

    output_path <- fs::path_join(output_path_segments)
    output_path_abs <- fs::path_join(c(output_dir, output_path))

    # Generate output file
    template_path_abs <- fs::path_join(c(template_dir, template_path))

    # Detect file type as well as possible
    template_mime <- mime::guess_type(template_path_abs)
    template_is_text <-
      !is.na(stringr::str_match(template_mime, '^text/')[1, 1])

    if (fs::file_exists(output_path_abs) && !overwrite) {
      rlang::inform(paste('Skipping existing file', output_path))
    } else if (template_is_text) {
      # Render content if text file
      rlang::inform(paste0('Rendering "', output_path, '"'))
      template_contents <- readr::read_file(template_path_abs)

      fs::dir_create(fs::path_dir(output_path_abs))
      readr::write_file(
        whisker::whisker.render(template_contents, context),
        output_path_abs
      )
    } else {
      # Copy content otherwise
      rlang::inform(paste('Copying', output_path, 'of type', template_mime))
      fs::dir_create(fs::path_dir(output_path_abs))
      fs::file_copy(template_path_abs, output_path_abs, overwrite = overwrite)
    }
  }
}
