# Common/backend.tf.scriban

terraform {
  
    backend "remote" {
      hostname = "app.terraform.io"
      organization = ""
      
      workspaces {
        name = ""
      }
    }
    
}
