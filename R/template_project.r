template_project <- function(path, ...) {
    # Collect further arguments
    dots <- list(...)

    # Pass on to bake function
    bake(
        dots$template,
        path,
        no_input=dots$no_input,
        overwrite=dots$overwrite
    )
}
