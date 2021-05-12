local constants = require "octo.constants"
local graphql = require "octo.graphql"
local util = require "octo.util"
local gh = require "octo.gh"

local M = {}

function M.open_in_browser()
  local bufnr = vim.api.nvim_get_current_buf()
  local buffer = octo_buffers[bufnr]
  if not buffer then return end
  local kind
  if buffer:isPullRequest() then kind = "pr" end
  if buffer:isIssue() then kind = "issue" end
  local cmd = string.format("gh %s view --web -R %s %d", kind, buffer.repo, buffer.number)
  os.execute(cmd)
end

function M.go_to_issue()
  local bufnr = vim.api.nvim_get_current_buf()
  local buffer = octo_buffers[bufnr]
  if not buffer then return end
  local current_repo = buffer.repo

  local repo, number = util.extract_pattern_at_cursor(constants.LONG_ISSUE_PATTERN)

  if not repo or not number then
    repo = current_repo
    number = util.extract_pattern_at_cursor(constants.SHORT_ISSUE_PATTERN)
  end

  if not repo or not number then
    repo, _, number = util.extract_pattern_at_cursor(constants.URL_ISSUE_PATTERN)
  end

  if repo and number then
    local owner, name = util.split_repo(repo)
    local query = graphql("issue_kind_query", owner, name, number)
    gh.run(
      {
        args = {"api", "graphql", "-f", string.format("query=%s", query)},
        cb = function(output, stderr)
          if stderr and not util.is_blank(stderr) then
            vim.api.nvim_err_writeln(stderr)
          elseif output then
            local resp = vim.fn.json_decode(output)
            local kind = resp.data.repository.issueOrPullRequest.__typename
            if kind == "Issue" then
              util.get_issue(repo, number)
            elseif kind == "PullRequest" then
              util.get_pull_request(repo, number)
            end
          end
        end
      }
    )
  end
end

function M.next_comment()
  local bufnr = vim.api.nvim_get_current_buf()
  local buffer = octo_buffers[bufnr]
  if buffer.kind then
    local cursor = vim.api.nvim_win_get_cursor(0)
    local current_line = cursor[1]
    local lines = util.get_sorted_comment_lines()
    if not buffer:isReviewThread() then
      -- skil title and body
      lines = util.tbl_slice(lines, 3, #lines)
    end
    if not lines or not current_line then return end
    local target
    if current_line < lines[1]+1 then
      -- go to first comment
      target = lines[1]+1
    elseif current_line > lines[#lines]+1 then
      -- do not move
      target = current_line - 1
    else
      for i=#lines, 1, -1 do
        if current_line >= lines[i]+1 then
          target = lines[i+1]+1
          break
        end
      end
    end
    vim.api.nvim_win_set_cursor(0, {target+1, cursor[2]})
  end
end

function M.prev_comment()
  local bufnr = vim.api.nvim_get_current_buf()
  local buffer = octo_buffers[bufnr]
  if buffer.kind then
    local cursor = vim.api.nvim_win_get_cursor(0)
    local current_line = cursor[1]
    local lines = util.get_sorted_comment_lines()
    lines = util.tbl_slice(lines, 3, #lines)
    if not lines or not current_line then return end
    local target
    if current_line > lines[#lines]+2 then
      -- go to last comment
      target = lines[#lines]+1
    elseif current_line <= lines[1]+2 then
      -- do not move
      target = current_line - 1
    else
      for i=1, #lines, 1 do
        if current_line <= lines[i]+2 then
          target = lines[i-1]+1
          break
        end
      end
    end
    vim.api.nvim_win_set_cursor(0, {target+1, cursor[2]})
  end
end

return M
