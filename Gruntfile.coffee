module.exports = (grunt)->
  pkg = grunt.file.readJSON 'package.json'
  grunt.initConfig
    pkg: pkg

    webfont:
      '6x6_fat':
        src: 'tmp/6x6_fat.svg'
        dest: 'dest'
        options:
          font: '6x6_fat'
          htmlDemo: true
      '8x8':
        src: 'tmp/8x8.svg'
        dest: 'dest'
        options:
          font: '8x8'
          htmlDemo: true
      '8x8_bold':
        src: 'tmp/8x8_bold.svg'
        dest: 'dest'
        options:
          font: '8x8_bold'
          htmlDemo: true
      '8x8_border':
        src: 'tmp/8x8_border.svg'
        dest: 'dest'
        options:
          font: '8x8_border'
          htmlDemo: true

    clean:
      dest: ["dest/*", "tmp/*"]

    watch:
      font:
        files: ['src/**/*']
        tasks: ['compile']

  (grunt.loadNpmTasks task if task.match /^grunt\-/) for task of pkg.devDependencies

  grunt.registerTask 'compile', ['webfont']
  grunt.registerTask 'default', ['compile', 'watch']
