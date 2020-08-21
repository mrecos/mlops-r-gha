library(azuremlsdk)
cat("Completed package load\n")

library(jsonlite)
cat("Loaded jsonlite\n")
AZURE_CREDENTIALS=Sys.getenv("AZURE_CREDENTIALS")
cat("Read creds from ENV\n")
if(nchar(AZURE_CREDENTIALS)==0) stop("No AZURE_CREDENTIALS")
cat("Found Credentials\n")

creds <- fromJSON(AZURE_CREDENTIALS)
if(length(creds)==0) stop("Malformed AZURE_CREDENTIALS")
cat("Read Credentials\n")

TENANT_ID <- creds$tenantId
SP_ID <- creds$clientId
SP_SECRET <- creds$clientSecret
SUBSCRIPTION_ID <- creds$subscriptionId
cat(TENANT_ID,"\n",
   SP_ID,"\n",
   SP_SECRET,"\n",
   SUBSCRIPTION_ID,"\n")

workspace.json <- fromJSON("../.cloud/.azure/workspace.json")
cat("Read Workspace\n")

WSRESOURCEGROUP <- workspace.json$resource_group
WSNAME <- workspace.json$name
cat(WSRESOURCEGROUP,"\n",
   WSNAME,"\n")

compute.json <- fromJSON("../.cloud/.azure/compute.json")
CLUSTER_NAME <- compute.json$name
cat(CLUSTER_NAME,"\n")

svc_pr <- service_principal_authentication(tenant_id=TENANT_ID,
                                           service_principal_id=SP_ID,
                                           service_principal_password=SP_SECRET)
cat("Connected Service Principal\n")

ws <- get_workspace(WSNAME,
                    SUBSCRIPTION_ID,
                    WSRESOURCEGROUP, auth=svc_pr)

cat("Found workspace\n")

compute_target <- get_compute(ws, cluster_name = CLUSTER_NAME)
if (is.null(compute_target)) {
  vm_size <- "STANDARD_D2_V2" 
  compute_target <- create_aml_compute(workspace = ws,
                                       cluster_name = CLUSTER_NAME,
                                       vm_size = vm_size,
                                       min_nodes = 0,
                                       max_nodes = 2)

  wait_for_provisioning_completion(compute_target, show_output = TRUE)
}

cat("Found cluster\n")

ds <- get_default_datastore(ws)
target_path <- "accidentdata"

download_from_datastore(ds, target_path=".", prefix="accidentdata")

exp <- experiment(ws, "accident")

cat("Submitting training run\n")
cat(ds$path(target_path),"\n")

est <- estimator(source_directory=".",
                 entry_script = "accident-glm.R",
                 script_params = list("--data_folder" = ds$path(target_path)),
                 compute_target = compute_target)
cat("Created Estimator\n")

run <- submit_experiment(exp, est)
cat("Submitted Run\n")

wait_for_run_completion(run, show_output = TRUE)

cat("Training run complete.\n")

download_files_from_run(run, prefix="outputs/")
