---
title: iview上传图片至阿里云
date: 2020-03-11 10:34:39
tags:
categories:
 - 前端
 - vue
 - iview
---
# iView上传图片至阿里云

## 在iView Upload组件提供的demo上进行修改

> UploadPicture.vue
```
<template>
  <div>
    <div class="demo-upload-list" v-for="(item, index) in uploadList" :key="index">
      <template v-if="item.status === 'finished'">
        <ImagePdf :src="item.url" :in-modal="false" />
        <div class="demo-upload-list-cover">
          <Icon type="ios-eye-outline" @click.native="handleView(item)"></Icon>
          <Icon v-show="!disabled" type="ios-trash-outline" @click.native="handleRemove(item)"></Icon>
        </div>
      </template>
      <template v-else>
        <Progress v-if="item.showProgress" :percent="item.percentage" hide-info></Progress>
      </template>
    </div>
    <!-- 用v-show非v-if是利用了v-show的特性, 因为删除时需要使用到该组件 -->
    <Upload
      v-bind="$attrs"
      v-on="$listeners"
      :default-file-list="defaultList"
      :disabled="disabled"
      v-show="uploadList.length < uploadNumber"
      ref="upload"
      :action.sync="uploadUrl"
      :data="uploadData"
      :show-upload-list="false"
      :on-success="handleSuccess"
      :format="fileTypes"
      :max-size="maxSize"
      :on-format-error="handleFormatError"
      :on-exceeded-size="handleMaxSize"
      :before-upload="handleBeforeUpload"
      :multiple="false"
      type="drag"
      style="display: inline-block;width:80px;">
      <div class="upload-btn">
        <Icon type="ios-add" size="20"></Icon>
        <span>{{uploadText}}</span>
      </div>
    </Upload>
    <Modal title="查看" v-model="visible">
      <ImagePdf :src="imgSrc" v-if="visible" style="width: 100%;"></ImagePdf>
    </Modal>
  </div>
</template>

<script>
  import ImagePdf from './PdfView'
  export default {
    name: 'UploadPicture',
    components: {
      ImagePdf: PdfView
    },
    props: {
      defaultList: {
        type: Array,
        default: () => []
      },
      disabled: {
        type: Boolean,
        default: false
      },
      fileTypes: {
        type: Array,
        default: () => {
          return ['JPG', 'JPEG', 'PNG', 'PDF']
        }
      },
      uploadBusiType: {
        type: String,
        default: '01' // 业务类型-自定义业务类型
      },
      uploadNumber: {
        type: Number,
        default: 1
      },
      maxSize: {
        type: Number,
        default: 5 * 1024 * 1024
      },
      uploadText: {
        type: String,
        default: '点击上传'
      },
      onlyShow: {
        type: Boolean,
        default: false
      }
    },
    data () {
      return {
        uploadData: {},
        uploadUrl: '',
        imgSrc: '',
        visible: false,
        uploadList: []
      }
    },
    watch: {
      defaultList: {
        handler (c, v) {
          this.$nextTick(() => {
            this.uploadList = this.$refs.upload.fileList
          })
        },
        deep: true,
        immediate: true
      }
    },
    methods: {
      handleView (file) {
        this.imgSrc = file.url
        this.visible = true
      },
      transfer () { // 通知父级
        this.$nextTick(() => {
          this.$emit('on-change', this.uploadList)
        })
      },
      handleRemove (file) {
        const fileList = this.$refs.upload.fileList
        this.$refs.upload.fileList.splice(fileList.indexOf(file), 1)
        this.transfer()
      },
      async handleSuccess (res, file) {
        let path = this.uploadData.key
        let result = await this.getRealUrl(path)
        file.url = result
        file.key = path
        this.$Message.success('上传成功')
        const {name} = file
        const arrayIndex = this.uploadList.findIndex(it => it.name === name)
        this.$set(this.uploadList, arrayIndex, file) // 强制渲染
        this.transfer()
      },
      async getRealUrl (path) {
        let {data: {data}} = await this.$http.querySsoTempUrl({
          filePath: path
        })
        return data
      },
      handleFormatError (file) {
        this.$Notice.warning({
          title: '文件格式不支持',
          desc: '当前文件 ' + file.name + ' 不支持！'
        })
      },
      handleMaxSize (file) {
        this.$Notice.warning({
          title: '文件过大',
          desc: '文件  ' + file.name + ' 太大，最大支持5M'
        })
      },
      handleBeforeUpload (file) {
        return new Promise((resolve, reject) => {
          if (this.uploadList && (this.uploadList.length > this.uploadNumber)) {
            this.$Notice.destroy()
            this.$Notice.warning({
              title: '文件数量太多',
              desc: `只允许上传${this.uploadNumber}个文件!`
            })
            // eslint-disable-next-line prefer-promise-reject-errors
            reject(false)
          }
          this.initOssConfigure(file).then(res => {
            resolve(res)
          })
        })
      },
      // 异步获取Oss的相关参数
      async initOssConfigure (file) {
        let query = {
          uploadBusiType: this.uploadBusiType,
          uploadFileName: file.name,
          timestamp: this.timestamp,
          merchantNo: this.merchantNo
        }
        try {
          let res = null
          if (this.loginStatus) {
            res = await this.$http.getUploadOssFileParams(query)
          } else {
            res = await this.$http.getUploadOssFileParamsWithNotLogin(query)
          }
          let {data: {data}} = res
          data['Content-type'] = file.type
          this.uploadUrl = data.url
          data['OSSAccessKeyId'] = data.ossAccessKeyId
          delete data.url
          delete data.ossAccessKeyId
          this.uploadData = data
          return true
        } catch (e) {
          console.error('获取oss上传参数失败!', e)
          return false
        }
      }
    },
    mounted () {
      this.uploadList = this.$refs.upload.fileList
    }
  }
</script>

<style scoped lang="less" type="text/less">
  .demo-upload-list {
    display: inline-block;
    width: 80px;
    height: 80px;
    text-align: center;
    line-height: 80px;
    border: 1px solid transparent;
    border-radius: 4px;
    overflow: hidden;
    background: #fff;
    position: relative;
    box-shadow: 0 1px 1px rgba(0, 0, 0, .2);
    margin-right: 4px;
  }

  .demo-upload-list img {
    width: 100%;
    height: 100%;
  }

  .demo-upload-list-cover {
    display: none;
    position: absolute;
    top: 0;
    bottom: 0;
    left: 0;
    right: 0;
    background: rgba(0, 0, 0, .6);
  }

  .demo-upload-list:hover .demo-upload-list-cover {
    display: block;
  }

  .demo-upload-list-cover i {
    color: #fff;
    font-size: 20px;
    cursor: pointer;
    margin: 0 2px;
  }

  .upload-btn {
    width: 80px;
    height: 80px;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-content: center;
    box-sizing: border-box;
    padding: 5px;
  }
</style>
```

> PdfView.vue // 主要是为了上传的若是pdf，预览可以查看
> 

```
<template>
  <div class="show-div">
    <template v-if="isPdf">
      <template v-if="inModal">
        <embed style="width: 100%;height: 600px;" :src="src" type="">
      </template>
      <template v-else>
        <div class="font-desc">
          <p>pdf文件请通过查看预览</p>
        </div>
      </template>
    </template>
    <template v-else>
      <img :src="src" alt="">
    </template>
  </div>
</template>

<script>
  export default {
    name: 'ImagePdf',
    props: {
      src: {
        type: String,
        default: ''
      },
      inModal: {
        type: Boolean,
        default: true
      }
    },
    data () {
      return {
        isPdf: false
      }
    },
    watch: {
      src: {
        handler (src) {
          if (src) {
            this.showHandler()
          }
        },
        immediate: true
      }
    },
    methods: {
      showHandler () {
        const {src} = this
        const path = src.split('?')[0]
        const type = path.substr(path.length - 3, path.length) // PDF, PNG
        this.isPdf = type.toUpperCase() === 'PDF'
      }
    }
  }
</script>

<style scoped lang="less" type="text/less">
  .show-div {
    width: 100%;
    height: 100%;

    img {
      width: 100%;
      height: 100%;
    }

    .font-desc {
      width: 100%;
      height: 100%;
      padding-top: 20px;
      p {
        height: 100%;
        line-height: 24px;
        font-size: 12px;
      }
    }
  }
</style>
```

> 在Form中调用
```
<template>
    <Form :form="formData" :rules="rules">
       <FormItem label="图片上传" prop="formData.picture">
         <UploadPicture
           @on-change="bindToForm"
           :disabled="basicInfoLock"
           :defaultList="authorizeForm.contactAuthLetterUrl"
         >
         </UploadPicture>
       </FormItem>
    </Form>
</template>
<script>
  import UploadPicture from './UploadPicture'
  export default {
    data () {
      return {
         formData: {
           picture: ''
         },
         rules: {
           picture: [
             { required: true, type: 'array', message: '图片不能为空', trigger: 'blur' }
           ]
         }
      }
    }
  }
</script>
```

> 结果:
![result](result.png)
