#!/bin/bash
# Modelink Workstation — Workspace Directory Structure

WORKSPACE_BASE="$HOME/Workspace"

declare -a DIRECTORIES=(
  "${WORKSPACE_BASE}/Projects"
  "${WORKSPACE_BASE}/Clients"
  "${WORKSPACE_BASE}/Research"
  "${WORKSPACE_BASE}/Agents"
  "${WORKSPACE_BASE}/AI"
  "${WORKSPACE_BASE}/AI/Models"
  "${WORKSPACE_BASE}/AI/Datasets"
  "${WORKSPACE_BASE}/AI/Agents"
  "${WORKSPACE_BASE}/AI/Inference"
  "${WORKSPACE_BASE}/Containers"
  "${WORKSPACE_BASE}/Infrastructure"
  "${WORKSPACE_BASE}/Infrastructure/Terraform"
  "${WORKSPACE_BASE}/Infrastructure/Ansible"
  "${WORKSPACE_BASE}/Infrastructure/Kubernetes"
  "${WORKSPACE_BASE}/Automation"
  "${WORKSPACE_BASE}/Automation/Scripts"
  "${WORKSPACE_BASE}/Automation/CI-CD"
  "${WORKSPACE_BASE}/Scripts"
  "${WORKSPACE_BASE}/Templates"
  "${WORKSPACE_BASE}/Templates/Project"
  "${WORKSPACE_BASE}/Templates/Agent"
  "${WORKSPACE_BASE}/Templates/Infrastructure"
  "${WORKSPACE_BASE}/Archives"
  "${WORKSPACE_BASE}/Backups"
)

for dir in "${DIRECTORIES[@]}"; do
  mkdir -p "$dir"
done

# Create .gitkeep files to preserve empty directories
find "$WORKSPACE_BASE" -type d -empty -exec touch {}/.gitkeep \;

echo "Workspace structure created at ${WORKSPACE_BASE}"
