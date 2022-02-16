# github-action-generate-ssm-documents
Automatically generates ssm documents

## Usage

This github action will automatically create an ssm document to run files uploaded into a given github repo. The files need ssm documents created can be determined by a prefix. The github repo can also be private.

### base_doc.yml

This file will need to be placed into the repo that you wish to upload your scripts to.

### Env Vars

``` yaml
FILE_LIST: This will be an auto generated list of all files that are uploaded to your scripts repo each commit.
PREFIX_FILTER: This is a string that will be used as a prefix to filter out files that are uploaded but not needed to be ssm documents.
DEBUG: Either True/False. This will give extra output useful for debugging.
AWS_REGION: An array of the regions to upload the created ssm files to
AWS_ACCESS_KEY_ID: The AWS access key used to upload the created ssm files. It is recommended to keep this as a github secret.
AWS_SECRET_ACCESS_KEY: The AWS secret access key used to upload the created ssm files. It is recommended to keep this as a github secret.
REPO_NAME: The name of the repo to monitor for file changes
REPO_OWNER: The repo owner
```

### workflow.yml example

```yaml
name: synchronizeSSM

on:
  push:
    branches: 
      - main

jobs:
  release:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2
      with: 
        fetch-depth: 0
    
    - name: get files changed
      uses: lots0logs/gh-action-get-changed-files@2.1.4
      id: get_files_changed
      with:
        token: ${{ secrets.GITHUB_TOKEN }}

    - name: generate ssm yaml file
      id: generate_ssm_yaml
      uses: owner/repo@main
      env:
        FILE_LIST: ${{ steps.get_files_changed.outputs.added }}
        PREFIX_FILTER: scripts
        DEBUG: True
        AWS_REGION: us-east-1
        AWS_ACCESS_KEY_ID: ${{ secrets.STAGING_AWS_ACCESS_KEY_ID }}
        AWS_SECRET_ACCESS_KEY: ${{ secrets.STAGING_AWS_SECRET_ACCESS_KEY }}
        REPO_NAME: repo
        REPO_OWNER: owner
```

## Release Management

You may skip this section unless you are working on developing this project's action yourself.

### Version Numbering

We follow [SemVer](https://semver.org/) as closely as possible. Please read up on it to pick the right next version number.

### Tagging the build

We tag from the default branch (currently known as `main`) and use the GitHub Actions "tag" workflow to do the actual tagging and pushing.

1. Navigate to this project's "Actions" tab and click the "tag" workflow.
2. On the right hand side, click "Run Workflow" below the "Filter workflow runs" search bar.
3. Keep the default `Use workflow from`, type the default branch name (`main`) as the branch to tag, and use the appropriate SemVer (`vX.Y.Z`) as detailed above.
4. Click "Run Workflow" and wait for it to complete.

This will add a new tag to the project for usage by downstream clients.

We do not currently use abbreviated versions (e.g. `v3`) for security and simplicity reasons. This means each downstream project will need to opt-in to the changes manually.
## License

This project is distributed under the [MIT license](LICENSE.md).
