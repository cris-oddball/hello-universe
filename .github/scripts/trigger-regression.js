// This script will be responsible for triggering a specified workflow, waiting for its completion, and then logging the conclusion.

const triggerAndWait = async ({ github, context }) => {
  const owner = 'cris-oddball'; // user of private repo 
  const repo = 'hello-world'; // private repo to contact
  const workflow_id = 'run-tests.yml'; // Replace with your workflow file name or ID
  const ref = 'main'; // Usually main or master

    // Define the inputs required by the workflow
  const inputs = {
    environment: 'perf', // Replace with the actual environment value or use dynamic input
  };

  // Trigger the workflow
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

  // Get the run ID of the triggered workflow
  let runs = await github.rest.actions.listWorkflowRuns({
    owner,
    repo,
    workflow_id,
    status: 'queued',
  });

  let run_id = runs.data.workflow_runs[0].id;
  console.log(`Triggered workflow run ID: ${run_id}`);

  // Wait for the workflow to complete
  let status;
  let conclusion;
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

  // Log the conclusion
  console.log(`Workflow conclusion: ${conclusion}`);
};

module.exports = triggerAndWait;


