// GitHub Actions helper (actions/github-script). Finds or creates the standing
// "Living user feedback inbox" issue and comments with living-users/INBOX.md.
"use strict";

const fs = require("fs");
const path = require("path");

const ISSUE_TITLE = "Living user feedback inbox";
const ISSUE_INTRO = `This issue is the **inbox for simulated living users** (personas that log workouts on the daily GitHub Action).

Each comment is one day's likes, dislikes, bugs, and UI/workflow notes, generated from their SwiftData stores. Tab screenshots live on the workflow artifact \`living-user-screenshots\`.

The nightly improvement loop should read the latest comment (or \`living-users/INBOX.md\` from the \`living-user-stores\` artifact) before picking product work.

Leave this issue open while the Living users workflow is active.
`;

module.exports = async function postLivingUserInbox({ github, context, core }) {
  const inboxPath = path.join(process.cwd(), "living-users", "INBOX.md");
  if (!fs.existsSync(inboxPath)) {
    throw new Error(
      `Missing ${inboxPath}. Ticks must write INBOX.md before this step.`
    );
  }
  const inbox = fs.readFileSync(inboxPath, "utf8").trim();
  if (!inbox) {
    throw new Error(`${inboxPath} is empty.`);
  }

  const { owner, repo } = context.repo;
  const issues = await github.paginate(github.rest.issues.listForRepo, {
    owner,
    repo,
    state: "open",
    per_page: 100,
  });
  let issue = issues.find((item) => item.title === ISSUE_TITLE && !item.pull_request);

  if (!issue) {
    const created = await github.rest.issues.create({
      owner,
      repo,
      title: ISSUE_TITLE,
      body: ISSUE_INTRO,
    });
    issue = created.data;
    core.info(`Created inbox issue #${issue.number}`);
  } else {
    core.info(`Using existing inbox issue #${issue.number}`);
  }

  const runUrl = `${context.serverUrl}/${owner}/${repo}/actions/runs/${context.runId}`;
  let commentBody = `From [Living users run ${context.runId}](${runUrl}).\n\n${inbox}\n`;
  const maxLen = 65000;
  if (commentBody.length > maxLen) {
    commentBody =
      commentBody.slice(0, maxLen - 80).trimEnd() +
      "\n\n_Truncated for GitHub comment size._\n";
  }

  await github.rest.issues.createComment({
    owner,
    repo,
    issue_number: issue.number,
    body: commentBody,
  });

  const issueUrl = issue.html_url || `https://github.com/${owner}/${repo}/issues/${issue.number}`;
  core.notice(`Posted living-user inbox to ${issueUrl}`);
  await core.summary
    .addHeading("Living user feedback inbox", 2)
    .addLink(`Issue #${issue.number}`, issueUrl)
    .addRaw("\n\nThe nightly loop should read the latest comment on that issue.\n")
    .write();
};
