# The Goal: Setup Gitea in Azure with some nice DevOps tools!

- **A couple of requirements:**

Must use Docker to run Gitea itself (You have to build the container yourself)

Must function properly if the virtual machine is rebooted without any manual intervention

Must use DNS and proper SSL setup (there’s more information about DNS names later)

Must have the process documented as a how-to, so I can read through and get your code running successfully. Include commands, comments, anything that would help someone get it going.

- **For a G:**

You must create the Gitea container yourself with Gitlab CI/CD and store it in the Gitlab Container registry of your project. Infrastructure must be deployed with Terraform, however configuration/installation can be done manually. The previous requirements will still apply (docker, reboot, DNS+SSL).

- **For a VG:**

Same as G + you have to automate the entire deployment process. Meaning that the docker container you created needs to be deployed automatically with Cloud-init or Ansible (or some other tools if you prefer) but it CANNOT have any manual actions (besides running the automation tools themselves).

- **For “strength” modifiers you can add:**

Compiling the Gitea code from scratch, producing binaries and then turning it into a Docker image

You can add load-balancing as well, keep in mind highly available Gitea is a bit of a pain.

Prometheus monitoring + Grafana

To request a DNS name, it must end with chas.dsnw.dev (for example: alex.chas.dsnw.dev ) write me an email to ************ with your public IP address and I’ll point the DNS to that location. I’m also working on some automation that might give you the ability to request one yourself!

**Submission:**

- Documentation (how-to) + Terraform code and/or anything else that you used to build the environment (like Ansible code, cloud-init scripts, CI/CD file and so on)