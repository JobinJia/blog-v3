---
title: upload上传至oss
date: 2020-06-22 18:45:10
tags:
categories: 
 - 前端
 - vue
 - ant-design
---


```
/**
* _utils中的两个方法
*/
// 获取默认的原组件中的props
export const getDefaultProps = (componentProps, vm) => {
  const props = Object.keys(componentProps).reduce((pre, cur) => {
    const stash = {}
    if (vm[cur]) {
      stash[cur] = vm[cur]
    }
    return {
      ...pre,
      ...stash
    }
  }, {})
  return props
}

// 获取文件名
export const fixFileSuffix = (fileName, oriFileName) => {
  const suffix = oriFileName.substring(oriFileName.lastIndexOf('.'))
  if (fileName.includes('.')) {
    fileName = fileName.substring(0, fileName.lastIndexOf('.')) + suffix
  } else {
    fileName = fileName + suffix
  }
  return fileName
}

/**
* Upload.vue
*
*/
import { UploadProps } from 'ant-design-vue/es/upload'
import { fixFileSuffix, getDefaultProps } from '../../_utils'

export default {
  name: 'BUpload',
  props: Object.assign({}, UploadProps, {
    uploadBusinessType: { // 上传文件的业务类型
      type: String,
      default: '',
      required: true
    },
    onlyOne: {
      type: Boolean,
      default: false
    }
  }),
  data () {
    return {
      uploadData: {},
      uploadUrl: ''
    }
  },
  methods: {
    async customBeforeUpload (file, fileList) {
      // 执行OSS参数获取
      const query = {
        uploadBusiType: this.uploadBusinessType,
        uploadFileName: this.fileName ? fixFileSuffix(this.fileName, file.name) : file.name,
        timestamp: new Date().getTime()
      }
      try {
        const { data } = await this.$http.system.getUploadOssFileParams(query)
        const { url, ossAccessKeyId, key } = data
        this.uploadUrl = url
        this.uploadData = {
          ...data,
          'Content-type': file.type,
          OSSAccessKeyId: ossAccessKeyId
        }
        this.$nextTick(() => {
          // 执行外层函数回调
          const { beforeUpload } = this
          if (beforeUpload) {
            // 插入OSS返回的相对路径
            const index = fileList.findIndex(it => it.uid === file.uid)
            file.relativePath = key
            fileList.splice(index, 1, file)
            beforeUpload(file, fileList)
          }
        })
      } catch (e) {
        console.error('获取oss上传参数失败!', e)
        // eslint-disable-next-line prefer-promise-reject-errors
        return Promise.reject(false)
      }
    },
    handleChange (info) {
      if (this.onlyOne && info.fileList.length >= 2) { // 如果只能传一个且长度大于2的时候执行
        let fileList = [...info.fileList]
        fileList = fileList.slice(-1) // 只支持上传1个
        fileList = fileList.map(file => {
          if (file.response) {
            file.url = file.response.url
          }
          return file
        })
        info.file = fileList[0]
        info.fileList = fileList
      }
      // if (info.file.status !== 'uploading') {
      //   console.log(info.file, info.fileList, info.event)
      // }
      if (info.file.status === 'done') {
        this.$message.success(`${info.file.name}上传成功`)
      } else if (info.file.status === 'error') {
        this.$message.error(`${info.file.name} 上传失败 : (`)
      }
      const { change } = this.$listeners
      change && change(info)
    },
    fillUploadParams (props) {
      props.action = this.uploadUrl
      props.data = this.uploadData
    }
  },
  render () {
    const props = getDefaultProps(UploadProps, this)
    // 插入beforeUpload
    props.beforeUpload = this.customBeforeUpload
    // 补充上传参数
    this.fillUploadParams(props)
    return (
      <a-upload
        {...{ props }}
        {...{
          on: {
            change: this.handleChange
          }
        }}
      >
        {
          Object.keys(this.$slots).map(name => {
            return this.$slots[name]
          })
        }
      </a-upload>
    )
  }
}


```
