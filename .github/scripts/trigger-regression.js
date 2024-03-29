// This script will be responsible for triggering a specified workflow, waiting for its completion, and then logging the conclusion.

const triggerAndWait = async ({ github, context }) => {
  const owner = 'cris-oddball'; // user of private repo 
  const repo = 'hello-world'; // private repo to contact
  const workflow_id = 'run-tests.yml'; // Replace with your workflow file name or ID
  const ref = 'main'; // Usually main or master
  const jobName = 'Run tests'; // Replace with the name of the job you want

  // Define the inputs required by the workflow
  const inputs = {
    environment: 'perf', // Replace with the actual environment value or use dynamic input
  };

  // Create a timestamp for workflow run tracking
  const triggerTimestamp = new Date().toISOString();
  console.log(`Triggering workflow: ${workflow_id} on ${owner}/${repo}`);
  await github.rest.actions.createWorkflowDispatch({
    owner,
    repo,
    workflow_id,
    ref,
    inputs,
  });

  // Wait a moment for the workflow run to be initialized
  await new Promise(r => setTimeout(r, 5000));

  // Poll for the workflow run using the timestamp
  let run_id;
  while (!run_id) {
    const runs = await github.rest.actions.listWorkflowRuns({
      owner,
      repo,
      workflow_id,
      created: `>=${triggerTimestamp}`
    });

    if (runs.data.workflow_runs.length > 0) {
      run_id = runs.data.workflow_runs[0].id;
      break;
    }

    await new Promise(r => setTimeout(r, 1000));
  }

  console.log(`Triggered workflow run ID: ${run_id}`);

  // Wait for the workflow to complete
  let status;
  let conclusion;
  let workflow_url = `https://github.com/${owner}/${repo}/actions/runs/${run_id}`;
  do {
    await new Promise(r => setTimeout(r, 10000)); // Poll every 10 seconds
    const result = await github.rest.actions.getWorkflowRun({
      owner,
      repo,
      run_id,
    });
    status = result.data.status;
    conclusion = result.data.conclusion;
    console.log(`Current status: ${status}`);
  } while (status !== 'completed');

  // Log the conclusion and the workflow URL
  console.log(`Workflow conclusion: ${conclusion}`);
  console.log(`Workflow run URL: ${workflow_url}`);

  // Fetch the job within the workflow run
  const jobs = await github.rest.actions.listJobsForWorkflowRun({
    owner,
    repo,
    run_id,
  });

  const job = jobs.data.jobs.find(j => j.name === jobName);
  if (!job) {
    console.log(`Job '${jobName}' not found in workflow run.`);
    return;
  }

  let job_id = job.id;

  // Fetch and handle the job logs
  github.rest.actions.downloadJobLogsForWorkflowRun({
    owner,
    repo,
    job_id,
  }).then(response => {
    console.log(`Job logs: ${response.data}`);
  }).catch(error => {
    console.log('Error fetching job logs:', error);
  });

    // Check if the workflow failed and throw an error if so
  if (conclusion !== 'success') {
    console.error(`Workflow failed. Conclusion: ${conclusion}`);
    throw new Error('Triggered workflow failed, causing this action to fail.');
  }

};

module.exports = triggerAndWait;


