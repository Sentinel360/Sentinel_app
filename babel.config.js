module.exports = function(api) {
  api.cache(true);
  return {
    presets: ['babel-preset-expo'],
    // NOTE: Do NOT add react-native-reanimated/plugin here
    // It causes worklets errors in Expo Go
  };
};
