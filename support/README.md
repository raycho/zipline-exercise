# Programming Exercise - Support Engineer

## Context

As a Support Engineer, your role may require you to access and manipulate production data and integrations to help
customers leverage the Zipline platform. As you may be working with live data (and the work we do impacts hundreds of
thousands of retail workers!), you need to be _extremely_ precise. We don't want customers losing data
or being adversely impacted by these manipulations!

In this exercise, you will be provided with a list of user accounts. For convenience, in the context of this assignment,
this list is provided as a CSV file.

**Your job: Identify potential duplicates among this list of users!**

However, customers can have differing requirements as to what constitutes a 'potential duplicate': for some customers,
identical email addresses or phone numbers constitute duplicate users - but others may reuse email addresses across
employees, only have one phone number for all employees at a given store, and so on! This requires you to be
flexible to meet the customer's requirements.

## Guidelines

### Expected Output

Your code should provide its output in the form of a CSV file. This CSV should contain the original input file's
contents (also a CSV - see the included sample files), as well as an additional `user_id` column identifying potential
duplicate rows. Different users should have different identifiers; potential duplicates should have the same identifier!

In the context of this assignment, potential duplicates can come in two different flavors: they can be identified based
on their **phone numbers**, or they can be duplicates based on their **email addresses**. They can also be identified
through a **combination of both** (either the phone number or the email is the same).

Your submission is expected to allow us to identify duplicate rows in each of the three provided sample CSV files, using
either of the three flavors identified above.

### Running your program
The entry point for your code should be the `match_users.rb` file provided in this repository. The program should take
at least two parameters: a **list of one or more matching type(s)**, as well as an **input file**.

```bash
ruby match_users.rb <..one_or_more_matching_types> <input_filename.csv>
```

For instance, this command would allow you to identify duplicate users in the `input1.csv` file by **email addresses**
only:
```bash
ruby match_users.rb email input1.csv
```

While this command would allow you to identify duplicate users in the `input2.csv` file by **either emails OR phone
numbers**:

```bash
ruby match_users.rb email phone input2.csv
```

### Sample CSV Files

Three unique sample input files have been provided as a reference. Your program should be able to process each of these
files accurately!

### Coding

A few notes on coding your submission:
- Complete this assignment using the Ruby programming language;
- Follow engineering and programming best practices. We don't enforce a specific coding style guide, but your code is
  expected to be readable and consistent;
- Only use code that you have license to use - but try to limit the use of external libraries or gems!
- Please do not overwrite the original input files!
- **Please do NOT publicly fork this repository!** Instead, clone the repository and email your submission to us in a ZIP
file!

**Most importantly: don't hesitate to ask us any clarifying questions!**

## Scoring Guide

### Running Your Program
- [ ] Does this run from command line as instructed?
- [ ] Does it run without errors?

### Output Format
- [ ] Is the output written to a CSV file?
- [ ] Does the CSV file contain the input file's original content?
- [ ] Is there an additional `user_id` column included?

### Assignment Requirements
- [ ] Can your code identify duplicates in a single column (phone / email)?
- [ ] Can your code identify duplicates across multiple columns of a similar type (phone / email)? (i.e. if there are
  multiple phone columns in a file, can you identify duplicates across all columns?)
- [ ] Are you able to identify duplicates across multiple columns of a different type (phone / email)? (i.e. can you
  identify duplicates by email address OR phone number?)
- [ ] Are phone numbers and emails standardized?

### Coding Style 
- [ ] How readable is it?
- [ ] Is the coding style consistent?
- [ ] How extensible is the code?
- [ ] How maintainable is the code?
