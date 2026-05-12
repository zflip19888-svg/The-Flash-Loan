module.exports = {
  semi: true,
  singleQuote: false,
  tabWidth: 2,
  trailingComma: "es5",
  printWidth: 100,
  bracketSpacing: true,
  arrowParens: "always",
  overrides: [
    {
      files: "*.sol",
      options: {
        printWidth: 100,
        tabWidth: 4,
        singleQuote: false,
        bracketSpacing: false,
        explicitTypes: "always",
      },
    },
  ],
};
