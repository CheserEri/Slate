# Slate

Slate 是一个本地相册管理工具，采用**玻璃拟态 + OLED 沉浸**设计风格，支持浏览本地照片和通过 SMB 协议备份到远程服务器。

## 项目结构

```
Slate/
├── lib/                  # 后端 (Dart Shelf)
│   ├── main.dart         # 后端入口
│   ├── api/
│   │   └── router.dart   # REST API 路由
│   ├── models/
│   │   └── models.dart   # 数据模型
│   └── services/
│       ├── local_photo_service.dart  # 本地照片扫描
│       ├── smb_photo_service.dart    # SMB 操作
│       └── transfer_service.dart     # 上传/下载任务
├── app/                  # 前端 (Flutter Android)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/       # 前端数据模型
│   │   ├── providers/    # Riverpod 状态管理
│   │   ├── screens/      # 页面
│   │   ├── services/     # API 客户端
│   │   ├── widgets/      # UI 组件 (玻璃容器、动画等)
│   │   └── utils/        # 工具类
│   └── android/          # Android 配置
├── pubspec.yaml          # 后端依赖
└── app/pubspec.yaml      # 前端依赖
```

## 功能特性

- **本地相册**：按日期时间轴浏览手机本地照片
- **相册网格**：沉浸式网格浏览本地与远程相册
- **SMB 备份**：一键将本地照片同步到 SMB 共享目录
- **远程浏览**：在线浏览 SMB 服务器上的相册，支持子目录导航
- **传输队列**：管理上传/下载任务，支持暂停/继续
- **玻璃拟态设计**：深色 OLED 沉浸风格，高斯模糊卡片，纯黑背景
- **流畅动画**：页面淡入淡出、列表 stagger 滑入、按钮弹性反馈、图片渐显
- **Android 16 适配**：targetSdk 36，支持最新 Android 特性

## 快速开始

### 启动后端

```bash
cd Slate
dart run bin/main.dart --port 8080 --local-root ./photos
```

### 运行前端

```bash
cd Slate/app
flutter run
```

## API 端点

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/health` | 健康检查 |
| GET | `/local/albums` | 获取本地相册列表 |
| GET | `/local/albums/<path>/items` | 获取相册内照片 |
| POST | `/smb/servers` | 添加 SMB 服务器 |
| GET | `/smb/servers` | 列出 SMB 服务器 |
| GET | `/smb/servers/<id>` | 获取服务器详情 |
| DELETE | `/smb/servers/<id>` | 删除服务器 |
| POST | `/smb/servers/<id>/connect` | 测试连接 |
| GET | `/smb/servers/<id>/albums` | 获取远程相册 |
| GET | `/smb/servers/<id>/items` | 获取远程照片 |
| POST | `/smb/servers/<id>/download` | 下载文件 |
| POST | `/smb/servers/<id>/upload` | 上传文件 |
| GET | `/transfers` | 获取传输任务 |
| DELETE | `/transfers/<id>` | 取消任务 |
| POST | `/transfers/<id>/pause` | 暂停任务 |
| POST | `/transfers/<id>/resume` | 继续任务 |

## 技术栈

- **后端**：Dart + Shelf
- **前端**：Flutter + Riverpod
- **SMB 操作**：smbclient CLI
- **本地照片**：photo_manager 插件
- **UI 风格**：玻璃拟态 (Glassmorphism) + OLED 深色沉浸

## License

MIT
