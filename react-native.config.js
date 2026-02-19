module.exports = {
  dependency: {
    platforms: {
      android: {
        sourceDir: './android',
        packageImportPath: 'import com.backgroundlocation.RNBackgroundLocationPackage;',
        packageInstance: 'new RNBackgroundLocationPackage()',
      },
      ios: {
        podspecPath: './RNBackgroundLocation.podspec',
      },
    },
  },
};

