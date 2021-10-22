---
title: iView多表单验证
date: 2020-03-16 09:48:59
tags:
categories:
 - 前端
 - vue
 - iview
---
## 利用Array.every实现多表单验证

> 如果页面有多个表单,可这么来实现，减少代码量

``` 
  <template>
    <Row>
      <Col>
        <Form ref="ref1">
        </Form>
        <Form ref="ref2">
        </Form>
        <Form ref="ref2">
        </Form>
      </Col>
      <Col>
        <Button @click="submitHandler">提交</Button>
      </Col>
    </Row>
  </template>
  <script>
    export default {
      name: 'FormComponent',
      data () {
        return {
          form1: {},
          form1Ruels: {},
          form2: {},
          form2Rules: {}
        } 
      },
      methods: {
        async submitHandler () {
          const formArray = ['form1', 'form2', 'form3']
          const validators = formArray.map(it => (this.$refs[it].validate(v => v)))
          // 一般的UI框架都基于async-form做的Form表单
          const validateResults = await Promise.all(validators)
          const v = validateResults.every(v => v)
          v && this.doPost()
        },
        async doPost () {
          const res = await axios.post(xxxx)
          console.log(res)
        }
      }
    }
  </script>
```
