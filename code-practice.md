# Code Practices
This is meant to provide a high level overview to our coding guidelines and approach to collaboration.

## Pull Requests
In order to merge code into the main branch you must create a pull request with approval from at least one other member to approve. To do this

1. Create a branch
2. Add appropriate changes
3. run `git add .` to stage changes
4. run `git commit -m "YOUR MESSAGE"` to commit changes
5. run `git push` to push your changes
6. Access the repository from github and view the pull request tab
7. Github should prompt you to create a new pull request from this branch. If it does not then click "New pull request" and select your branch. Then write a description for your changes and an appropriate title.

After another team member approves your changes, github will automatically merge your branch into main and delete the branch.

### Why use PRs?
There are many reasons why PRs are a good idea but here's two.
1. Say a line of code exists and you don't know why. PRs allow you to investigate the git blame on github and understand why that line exists. This makes it both easier to understand code and debug it
2. It removes the likely hood of bugs. It's very easy to make a silly change that actually doesn't compile or creates some kind of issue. Having pull requests means not only can others verify that the added lines make sense, it also allows us to create automations that block merging if the branch doesn't compile.

## Code Style
TODO

## Testing
TODO
