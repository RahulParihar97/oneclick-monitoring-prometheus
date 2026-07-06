stage('Terraform Apply') {
    when { expression { params.ACTION == 'APPLY' } }
    steps {
        dir(env.TF_DIR) {
            sh "terraform apply -auto-approve tfplan"
        }
    }
}

// --- All Ansible stages guarded with APPLY + RUN_ANSIBLE ---
stage('Ansible Inventory') {
    when { expression { params.ACTION == 'APPLY' && params.RUN_ANSIBLE } }
    steps {
        // ansible inventory commands
    }
}

stage('Configure Infrastructure') {
    when { expression { params.ACTION == 'APPLY' && params.RUN_ANSIBLE } }
    steps {
        // ansible-playbook
    }
}

// --- Deployment Summary ---
stage('Deployment Summary') {
    when { expression { params.ACTION == 'APPLY' } }
    steps {
        // summary output
    }
}

// --- Destroy LAST ---
stage('Terraform Destroy') {
    when { expression { params.ACTION == 'DESTROY' } }
    steps {
        dir(env.TF_DIR) {
            sh "terraform destroy -auto-approve"
        }
    }
}
