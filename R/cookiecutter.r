#' Fill a directory with files based on a cookiecutter template.
#'
#' This function takes a cookiecutter-compatible template directory and
#' resolves template placeholders in both filenames and (for text files)
#' content.
#'
#' @param template Template to apply
#' @param output_path Directory to fill
#' @param extra_context Context variables to use while populating template
#' @param overwrite Whether to overwrite existing files
#' @param no_input Don't prompt for context variables
#'  specified in cookiecutter.json
#'
#' @return None
#'
#' @details **template**
#'
#' Path to the template to apply. This can point to either a directory, or an
#' archive of the same in `.zip`, `.tar` or `.tar.gz` formats.
#'
#' @details **output_path**
#'
#' Path of directory to output processed template files into. This will be
#' filled based on the contents of the `template` option.
#'
#' @details **extra_context**
#'
#' List of template variables to use in filling placeholders. (empty by default)
#'
#' @details **overwrite**
#'
#' Whether to overwrite existing files. (defaults to `false`, and issues a
#' message)
#'
#' @details **no_input**
#'
#' Don't prompt the user for variable values specified in `cookiecutter.json`.
#' This removes the need for interaction when applying a template.
#'
#' @examples
#' # Extract a demo template
#' # (this uses a bundled template and extracts information
#' # into a temporary directory -- you'll have it easier
#' # because you can insert the paths you want directly)
#' cookiecutter::bake(
#'   system.file('examples/demo.zip', package = 'cookiecutter'),
#'   fs::path_temp('cookiecutter.demo'),
#'   extra_context = list(
#'     flavor = 'chocolate chip',
#'     hot_beverage = 'coffee'
#'   )
#' )
#'
#' @export
bake <- function(
  template,
  output_path,
  extra_context=list(),
  overwrite=FALSE,
  no_input=FALSE
) {
  # Supported archive file types
  archive_mimes <- c(
    'application/gzip',
    'application/x-tar',
    'application/zip'
    # TODO: could add .tar.xz; .tar.bz2 doesn't seem to be recognized by mime
  )

  if (missing(output_path)) {
    rlang::abort(paste(
      'Please specify an output path.',
      'We would like to make sure the files go where you want them,',
      'so we\'d rather not guess.'
    ))
  }

  # Use template directory or extract archive if required
  if (fs::is_dir(template)) {
    template_dir <- template
    archive_target <- NA
  } else if (
    fs::is_file(template) &&
    mime::guess_type(template) %in% archive_mimes
  ) {
    archive_target <- fs::path_temp('cookiecutter.archive')
    fs::dir_create(archive_target)

    switch (mime::guess_type(template),
      'application/gzip' = utils::untar(template, exdir = archive_target),
      'application/x-tar' = utils::untar(template, exdir = archive_target),
      'application/zip' = utils::unzip(template, exdir = archive_target),
    )

    template_dir <- archive_target
  } else {
    rlang::abort(paste(
      'Can\'t figure out what to do with template', template, '\u2013',
      'it doesn\'t look like a directory,',
      'nor like an archive file I can work with (.zip, .tar.gz).',
      'Could you take a look please?'
    ))
  }

  # Check template directory status
  if (!fs::dir_exists(template_dir))
    rlang::abort(paste(
      'Template directory', template_dir, 'missing or not a directory.'
    ))

  # Check for available options
  options_path <- fs::path_join(c(template_dir, 'cookiecutter.json'))

  if (fs::file_exists(options_path)) {
    options <- jsonlite::fromJSON(options_path)
  } else {
    options <- list()
  }

  # Merge options and explicitly provided context
  # TODO: Compare order to original cookiecutter library, possibly merge later,
  # or skip values that are provided through extra_context entirely
  context_initial <- purrr::list_assign(options, !!!extra_context)

  # Verify context by asking for user input
  if (!no_input) {
    context <- prompt_for_config(context_initial)
  } else {
    context <- context_initial
  }

  # Generate files
  generate_files(
    template_dir,
    output_path,
    context,
    context_prefix='cookiecutter',
    exclude=c('cookiecutter.json'),
    overwrite=overwrite
  )

  # Clean up
  if (!is.na(archive_target)) {
    fs::dir_delete(archive_target)
  }
}
