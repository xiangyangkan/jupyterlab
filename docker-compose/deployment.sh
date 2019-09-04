export $(grep -v '^#' deployment.env | xargs -0)
