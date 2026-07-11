# Acceptance test results

Date: 2026-07-11T05:57:05Z
Board under test: `5029833129` (project-tasks-update)

- **PASS**: get_user_context → user Lalit (108480035)
{"message":"User context","user":{"id":"108480035","name":"Lalit","title":""},"account":{"tier":"pro","active_members_count":1,"is_during_trial":true,"products":[{"kind":"core","tier":"pro"}]},"favorites":[],"relevantBoards":[{"id":"5029833129","name":"project-tasks-update"}],"relevantPeople":[]}

- **PASS**: search(searchTerm=project, searchType=BOARD)
{"message":"Search results","data":[{"id":"5029833129","title":"project-tasks-update","url":"/projects/5029833129"}]}

- **PASS**: get_board_schema/info for board 5029833129
{"message":"Board schema retrieved","board_id":5029833129,"columns":[{"id":"name","title":"Name","type":"name","revision":"d885ed4b6fa936a2cbfbdc2c6599c327"},{"id":"project_owner","title":"Owner","type":"people","revision":"d885ed4b6fa936a2cbfbdc2c6599c327"},{"id":"project_status","title":"Status","type":"status","revision":"d885ed4b6fa936a2cbfbdc2c6599c327"},{"id":"date","title":"Due date","type":"date","revision":"d885ed4b6fa936a2cbfbdc2c6599c327"},{"id":"timerange","title":"Timeline","type":"timeline","revision":"d3f5d36d6615923c6f1719973fc194dd"},{"id":"priority","title":"Priority","type":"status","revision":"86275508ce45e59ac53a571f499262b2"},{"id":"text","title":"Notes","type":"text","revision":"49e6ab350342cec0c1cedd33f77a5ade"},{"id":"subtasks_mm55347w","title":"Subitems","type":"subtasks","revision":"5d3b88959b938f9e5656a315bdbcae77"}],"groups":[{"id":"new_group29179","title":"To-Do"},{"id":"new_group43041","title":"Completed"}]}

- **PASS**: create_item name='MCP acceptance test 20260711-112711' with status+due
{"message":"Item 2776936958 successfully created","item_id":"2776936958","item_name":"MCP acceptance test 20260711-112711","item_url":"https://apptonicais-team.monday.com/boards/5029833129/pulses/2776936958","board_id":5029833129}

ITEM_ID=2776936958
- **PASS**: change_item_column_values status → Done
{"message":"Item 2776936958 successfully updated","item_id":"2776936958","item_name":"MCP acceptance test 20260711-112711","item_url":"https://apptonicais-team.monday.com/boards/5029833129/pulses/2776936958","column_values":{"project_status":"{\"index\":1,\"changed_at\":\"2026-07-11T05:57:14.837Z\"}"}}

- **PASS**: create_update on item 2776936958
{"message":"Update 118905821 created on item 2776936958","update_id":"118905821","item_id":2776936958,"item_name":"MCP acceptance test 20260711-112711","item_url":"https://apptonicais-team.monday.com/boards/5029833129/pulses/2776936958"}

- **PASS**: delete_item 2776936958 (test cleanup)
{"message":"Item 2776936958 successfully deleted","item_id":"2776936958"}

## Natural language → MCP tool mapping (verified)

| Natural language | MCP tool(s) |
|------------------|-------------|
| Who am I in monday? | `get_user_context` |
| List / show my boards | `search` (`searchType=BOARD`) / `get_user_context` relevantBoards |
| Show schema for board X | `get_board_schema` / `get_board_info` |
| Create a task with status + due date | `create_item` then `change_item_column_values` |
| Update that item’s status | `change_item_column_values` |
| Add a comment | `create_update` |
| Delete this item | `delete_item` (confirm first in normal use) |
| Uncovered GraphQL ops | `all_monday_api` |

