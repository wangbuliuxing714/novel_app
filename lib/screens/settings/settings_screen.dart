body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: const Text('API配置'),
                  trailing: IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: () {
                      apiConfigController.toggleConfigMode();
                      Get.snackbar(
                        '提示', 
                        '已切换到${apiConfigController.isTextToSpeechMode.value ? "文本转语音" : "AI对话"}配置',
                      );
                    },
                  ),
                ),
                Obx(() {
                  if (apiConfigController.isTextToSpeechMode.value) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '文本转语音API配置',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: TextEditingController(
                              text: apiConfigController.ttsApiKey,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'API密钥',
                              hintText: '请输入硅基流动API密钥',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: apiConfigController.setTTSApiKey,
                          ),
                        ],
                      ),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI对话API配置',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: TextEditingController(
                              text: apiConfigController.apiKey,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'API密钥',
                              hintText: '请输入API密钥',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: apiConfigController.setApiKey,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: TextEditingController(
                              text: apiConfigController.baseUrl,
                            ),
                            decoration: const InputDecoration(
                              labelText: '基础URL',
                              hintText: '请输入基础URL',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: apiConfigController.setBaseUrl,
                          ),
                        ],
                      ),
                    );
                  }
                }),
              ],
            ),
          ),
        ],
      ), 