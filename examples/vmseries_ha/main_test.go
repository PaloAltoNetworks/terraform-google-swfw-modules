package vmseries_ha

import (
	"log"
	"testing"

	"github.com/PaloAltoNetworks/terraform-modules-swfw-tests-skeleton/pkg/testskeleton"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func CreateTerraformOptions(t *testing.T) *terraform.Options {
	varsInfo, err := testskeleton.GenerateTerraformVarsInfo("gcp")
	if err != nil {
		// Handle the error
		log.Fatalf("Error generating terraform vars info: %v", err)
	}

	// define options for Terraform
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: ".",
		VarFiles:     []string{"example.tfvars"},
		Vars: map[string]interface{}{
			"name_prefix": varsInfo.NamePrefix,
			"project":     varsInfo.GoogleProjectId,
			"org_id":      varsInfo.GoogleOrgId,
		},
		Logger:               logger.Default,
		Lock:                 true,
		Upgrade:              true,
		SetVarsAfterVarFiles: true,
	})

	return terraformOptions
}

func TestValidate(t *testing.T) {
	testskeleton.ValidateCode(t, nil)
}

func TestPlan(t *testing.T) {
	// define options for Terraform
	terraformOptions := CreateTerraformOptions(t)
	// prepare list of items to check
	assertList := []testskeleton.AssertExpression{}
	// plan test infrastructure and verify outputs
	testskeleton.PlanInfraCheckErrors(t, terraformOptions, assertList, "No errors are expected")
}

func TestApply(t *testing.T) {
	// define options for Terraform
	terraformOptions := CreateTerraformOptions(t)
	// prepare list of items to check
	assertList := []testskeleton.AssertExpression{}
	// deploy test infrastructure and verify outputs and check if there are no planned changes after deployment
	testskeleton.DeployInfraCheckOutputs(t, terraformOptions, assertList)
}

func TestIdempotence(t *testing.T) {
	// define options for Terraform
	terraformOptions := CreateTerraformOptions(t)
	// prepare list of items to check
	assertList := []testskeleton.AssertExpression{}
	// deploy test infrastructure and verify outputs and check if there are no planned changes after deployment
	testskeleton.DeployInfraCheckOutputsVerifyChanges(t, terraformOptions, assertList)
}
