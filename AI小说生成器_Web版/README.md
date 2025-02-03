# AI小说生成器 - Web版本

这是AI小说生成器的Web版本，可以在任何操作系统上运行。

## 运行要求

- Python 3.6或更高版本
- 现代浏览器（推荐Chrome、Firefox或Safari）

## 如何运行

1. 确保您的电脑已安装Python（Mac OS通常已预装Python）
2. 双击运行`start_novel_app.py`文件
   - 在Mac OS上：右键点击文件 -> 选择"打开方式" -> 选择"Python Launcher"
   - 或者在终端中运行：`python start_novel_app.py`
3. 应用会自动在您的默认浏览器中打开
4. 要停止应用，请在终端中按Ctrl+C（Mac上是Command+C）

## 注意事项

- 应用运行时请保持终端窗口开启
- 如果浏览器没有自动打开，请手动访问终端中显示的地址
- 所有数据都会保存在浏览器的本地存储中
- 建议定期导出重要的内容

## 常见问题

Q: 运行时提示"python不是内部或外部命令"？
A: 需要安装Python，请访问 https://www.python.org/downloads/ 下载安装

Q: 浏览器打开后显示空白页面？
A: 请尝试刷新页面，或使用Chrome浏览器打开

Q: 如何备份生成的内容？
A: 使用应用中的导出功能，将内容导出为文件保存

小说生成器使用说明

 功能介绍

这是一个基于多个AI大语言模型的小说生成器，支持以下功能：
- 自动生成小说大纲和章节内容
- 支持多个AI模型：Gemini Pro、Gemini Flash、通义千问、Deepseek
- 小说导出和分享功能
- 自定义API配置

 模型配置说明

 1. Gemini Pro / Gemini Flash
- 访问 [Google AI Studio](https://makersuite.google.com/app/apikey) 创建API密钥
  - 手机浏览器访问时请选择"请求桌面网站"
  - 需要登录Google账号
  - 点击"Create API key"按钮创建新密钥
- 在设置页面选择 Gemini Pro 或 Gemini Flash
- API地址: https://generativelanguage.googleapis.com/v1
- 将获取的API密钥填入API Key输入框

 2. 通义千问
- 访问 [阿里云控制台](https://dashscope.console.aliyun.com/) 创建API密钥
  - 支持手机浏览器直接访问
  - 使用阿里云账号登录
  - 进入"API Key管理"页面创建密钥
- 在设置页面选择通义千问模型
- API地址: https://dashscope.aliyuncs.com/compatible-mode/v1
- 将获取的API密钥填入API Key输入框
- 注意：通义千问API密钥不需要添加"Bearer "前缀

 3. Deepseek
- 访问 [Deepseek官网](https://platform.deepseek.com/) 注册账号
  - 注册并登录账号
  - 在"API Keys"页面生成新密钥
- 在设置页面选择Deepseek模型
- API地址: https://api.deepseek.com/v1
- 将获取的API密钥填入API Key输入框

 获取API密钥的通用建议
1. 建议使用手机Chrome等主流浏览器访问
2. 如遇到页面显示异常，可以：
   - 开启浏览器的"请求桌面网站"功能
   - 横屏使用以获得更好的显示效果
   - 必要时可以使用电脑访问
3. 复制API密钥时请确保：
   - 完整复制，不要漏掉字符
   - 注意区分字母大小写
   - 避免多余的空格

 使用步骤

1. 首次使用时，请先进入设置页面配置API：
   - 选择要使用的AI模型
   - 填入对应的API密钥
   - 确认API地址正确

2. 返回主页面，点击"新建小说"：
   - 输入小说标题
   - 选择小说类型
   - 设置生成参数（如章节数量等）
   - 点击生成按钮开始创作

3. 查看和导出：
   - 在主页面可以查看所有已生成的小说
   - 点击小说卡片进入详情页
   - 在详情页可以查看大纲和章节内容
   - 点击顶部分享按钮可以导出小说

 注意事项

1. API密钥安全：
   - 请妥善保管您的API密钥
   - 不要分享给他人
   - 定期更换密钥以确保安全

2. 使用限制：
   - 不同模型可能有不同的速率限制
   - 建议在生成较长篇幅时使用稳定的网络连接
   - 如遇到超时错误，可以尝试重新生成

3. 存储权限：
   - 导出功能需要存储权限
   - 首次使用时请授予应用存储权限
   - 导出的文件保存在设备的外部存储目录

 常见问题

1. API密钥无效
   - 检查密钥是否正确复制
   - 确认是否选择了正确的模型
   - 验证API密钥是否过期

2. 生成失败
   - 检查网络连接
   - 确认API配置正确
   - 查看错误提示信息

3. 导出失败
   - 确认已授予存储权限
   - 检查设备存储空间是否充足
   - 尝试重新导出

如有其他问题，请提供具体的错误信息以便我们协助解决。
