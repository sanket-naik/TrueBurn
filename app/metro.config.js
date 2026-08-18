// Metro reaches one directory up so the app imports the *same* engine the simulation
// proves, rather than a copy that silently drifts from it. `src/core/` has no platform
// imports precisely so this works — see REQUIREMENTS §9.
const { getDefaultConfig } = require('expo/metro-config');
const path = require('path');

const projectRoot = __dirname;
const repoRoot = path.resolve(projectRoot, '..');

const config = getDefaultConfig(projectRoot);

config.watchFolders = [repoRoot];
config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, 'node_modules'),
  path.resolve(repoRoot, 'node_modules'),
];
config.resolver.disableHierarchicalLookup = true;

// tsconfig `paths` only teaches the type checker. Metro resolves separately, so the
// same alias has to be declared here or `@core/report` compiles and then fails to
// bundle — green typecheck, red device.
config.resolver.extraNodeModules = {
  '@core': path.resolve(repoRoot, 'src/core'),
};

module.exports = config;
