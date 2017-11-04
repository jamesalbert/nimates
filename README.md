# nimates
a client library for the Postmates API written in Nim

###### version: 0.0.1

## Credentials

You'll need to get your `customer_id` and `key` from Postmate's developer page.
Credentials are stored in a json file like so:
```json
{
  "customer_id": "XXX_XXXXXXXXXX-XXX",
  "key": "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
}
```
Keep this file in the same directory as your script.

## Getting Started

Make sure you have `nim >= 0.17.2` with `nimble` installed as well.

You can clone this repo and run the example from the root directory with `nimble example`

Be sure to specify `-d:ssl` when compiling (I usually keep this in the .cfg file)

More documentation can be found at https://jamesalbert.github.io/nimates/nimates.html

## Contributing

This is a brand-new module. If you find bugs or features that need to be added, PR away!

Recommended way of contributing:
  - fork and clone the repo
  - run `nimble develop`, this will symlink this repo to your .nimble directory (changes are instant; no need for running `nimble install` over and over...)
  - test changes
  - write and generate docs
  - create a pr

## Tests

There are currently no tests :(
